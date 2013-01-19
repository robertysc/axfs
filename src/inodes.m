#import "inodes.h"
#include <sys/stat.h>


//use path
static int InodeNameComp(const void *x, const void *y) {
	int min;
	int retval;
	struct inode_struct *a = (struct inode_struct *) x;
	struct inode_struct *b = (struct inode_struct *) y;

	if (a == NULL)
		[NSException raise: @"a == NULL" format: @""];
	if (b == NULL)
		[NSException raise: @"a == NULL" format: @""];

	printf("a->name=%s  ",a->name);
	printf("b->name=%s\n",b->name);
	if (a->name == NULL)
		[NSException raise: @"a->name == NULL" format: @""];
	if (b->name == NULL)
		[NSException raise: @"b->name == NULL" format: @""];


	min = b->name->length;
	if (a->name->length < b->name->length)
		min = a->name->length;

	retval = strncmp(a->name->data,b->name->data, min);

	if (a->name->length == b->name->length)
		return retval;

	if (retval != 0)
		return retval;

	if (a->name->length > b->name->length)
		return 1;

	return -1;
}

@implementation Inodes

-(struct inode_struct *) allocInodeStruct {
	uint64_t d = sizeof(struct inode_struct);
	return (struct inode_struct *) [self allocData: &inodes chunksize: d];
}

-(struct inode_struct **) allocInodeList: (uint64_t) len {
	uint64_t d = sizeof(struct inode_struct *) * len;
	return (struct inode_struct **) [self allocData: &inode_list chunksize: d];
}

-(uint64_t *) allocNodeList: (uint64_t) len {
	uint64_t d = sizeof(uint64_t) * len;
	return (uint64_t *) [self allocData: &node_list chunksize: d];
}

-(void) placeInDirectory: (struct inode_struct *) inode {
	struct inode_struct *parent;
	NSString *directory;
	struct inode_struct **list;
	uint64_t pos;

	directory = [inode->path stringByDeletingLastPathComponent];

	parent = [paths findParentInodeByPath: directory];
	if (!parent) {
		return;
	}

	if (parent == inode) {
		return;
	}
	list = parent->list.inodes;
	pos = parent->list.position;
	parent->list.position++;
	list[pos] = inode;
}

-(void *) addInode_symlink: (struct inode_struct *) inode {
	const char *str;
	int err;

	str = [inode->path UTF8String];

	if (symlink.total < inode->size) {
		free(symlink.data);
		symlink.data = malloc(inode->size);
		symlink.total = inode->size;
	}

	err = readlink(str, symlink.data, inode->size);
	if (err < 0)
		[NSException raise: @"readlink" format: @"readlink() returned error# %i",err];
	//FIXME: actually copy data here

	return inode;
}

-(void *) addInode_devnode: (struct inode_struct *) inode {
	struct stat sb;
	const char *str;

	str = [inode->path UTF8String];
	stat(str, &sb);
	inode->size = sb.st_rdev;
	return inode;
}

-(void *) addInode_regularfile: (struct inode_struct *) inode {
	NSFileHandle *file;
	NSData *databuffer;
	uint64_t data_read = 0;
	NSUInteger d;
	struct entry_list *list;

	list = &inode->list;

	file = [NSFileHandle fileHandleForReadingAtPath: inode->path];

	if (file == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[NSException raise: @"Bad file" format: @"Failed to open file at path=%@ from %@",inode->path, [fm currentDirectoryPath]];
	}

	list->length = inode->size / acfg.page_size + 1;
	list->nodes = [self allocNodeList: list->length];

	while (data_read < inode->size) {
		void *page;
		void *ddata;
		databuffer = [file readDataOfLength: acfg.page_size];
		d = [databuffer length];
		data_read += d;
		printf("d = %llu data_read = %llu size = %llu \n", d, data_read,inode->size);
		ddata = [databuffer bytes];
		page = [aobj.pages addPage: ddata length: d];
		[aobj.nodes addPage: page];
	}

	[file closeFile];

	//FIXME: actually copy data
	return inode;
}

-(void *) addInode_directory: (struct inode_struct *) inode {
	NSDirectoryEnumerator *em;
	struct entry_list *list;
	NSString* file;
	uint64_t count = 0;
	NSString* path;

	//NSArray *dir  = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: inode->path error:nil];
	if ([inode->path isEqualToString: @""]) {
		path = inode->path;
		path = [[NSFileManager defaultManager] currentDirectoryPath];
		path = [[NSString alloc] initWithUTF8String: acfg.input];
	} else {
		path = inode->path;
	}
	em = [[NSFileManager defaultManager] enumeratorAtPath: path];
	[em skipDescendents];
	while ((file = [em nextObject])) {
		[em skipDescendents];
		count++;
	}

	list = &inode->list;
	list->length = count;
	list->inodes = [self allocInodeList: list->length];
	[paths addPath: inode];
	return inode;
}

-(void *) addInode: (NSString *) path {
	NSString *filetype;
	NSString *name;
	struct inode_struct *inode;
	NSDictionary *attribs;

	printf("\n1 inodes addInode='%s'\n",[path UTF8String]);

	attribs = [[NSFileManager alloc] attributesOfItemAtPath: path error: nil];
	name = [path lastPathComponent];
	inode = [self allocInodeStruct];
	inode->size = (uint64_t)[[attribs objectForKey:NSFileSize] unsignedLongLongValue];
	inode->path = path;
	printf(" a-inodes addInode '%s' '%i' 0x%08x\n",(void *)[name UTF8String], [name length],inode->name);
	inode->name = [aobj.strings addString: (void *)[name UTF8String] length: [name length]];
	printf(" b-inodes addInode '%s' '%i' 0x%08x\n",(void *)[name UTF8String], [name length],inode->name);
	inode->mode = [aobj.modes addMode: attribs];
	printf(" c-inodes addInode 0x%08x\n",aobj.modes);
	//redundant files
	filetype = [attribs objectForKey:NSFileType];
	if (filetype == NSFileTypeSymbolicLink) {
		[self addInode_symlink: inode];
	} else if (filetype == NSFileTypeCharacterSpecial) {
		[self addInode_devnode: inode];
	} else if (filetype == NSFileTypeBlockSpecial) {
		[self addInode_devnode: inode];
	} else if (filetype == NSFileTypeDirectory) {
		[self addInode_directory: inode];
	} else if (filetype == NSFileTypeRegular) {
		[self addInode_regularfile: inode];
	} else {
		if ([path isEqualToString: @""] != true) {
			[NSException raise: @"Bad file" format: @"Failed to open file at path=%@ from %@",path];
		}
		[self addInode_directory: inode];
		printf("fadsfa\n");
	}
	//if (filetype != NSFileTypeDirectory) {
		[self placeInDirectory: inode];
	//}

	printf("\n2 inodes addInode=0x%08X\n",inode);
	//ohh can't do that... inode->path = NULL;
	return inode;
}

-(id) fileSizeIndex {
	return fileSizeIndex;
}

-(id) nameOffset {
	return nameOffset;
}

-(id) numEntries {
	return numEntries;
}

-(id) modeIndex {
	return modeIndex;
}

-(id) arrayIndex {
	return arrayIndex;
}

-(uint64_t) processInode: (struct inode_struct *) inode j: (int) j {
	struct entry_list *list;
	uint64_t i;
	uint64_t array_index;
	char *s;

	if (inode == NULL) {
		[NSException raise: @"processInode:" format: @" inode == NULL j=%i",j];
	}
	if (inode->name == NULL) {
		[NSException raise: @"processInode:" format: @" inode->name == NULL j=%i",j];
	}
	if (inode->name->data == NULL) {
		[NSException raise: @"processInode:" format: @" inode->name->data == NULL j=%i",j];
	}
	s = malloc(1024);
	memset(s,0,1024);

	printf("Inodes processInode inode=0x%08x j=%i\n",inode,j);
	printf("Inodes processInode inode->name=0x%08x j=%i\n",inode->name,j);
	printf("Inodes processInode inode->name->data=0x%08x j=%i\n",inode->name->data,j);
	memcpy(s,inode->name->data,inode->name->length);
	printf("Inodes processInode= '%s' %i j=%i\n",s,inode->name->length,j);

	j++;

	printf("Inodes a0\n");
	[fileSizeIndex add: inode->size];
	printf("Inodes a1\n");
	[nameOffset add: inode->name->position];
	printf("Inodes a2\n");
	[numEntries add: inode->length];
	printf("Inodes a3\n");
	printf("Inodes modeIndex: inode->mode=0x%08x\n",inode->mode);
	printf("Inodes modeIndex: inode->mode->position=0x%08x\n",inode->mode->position);
	[modeIndex add: inode->mode->position];
	printf("Inodes a4\n");
	list = &inode->list;
	printf("Inodes a5\n");
	if (list->inodes != NULL) {
		printf("6 Inodes list->inodes=0x%08X list->length=%i\n",list->inodes,list->length);
		printf("7 Inodes list->inodes[0.%i]='0x%08X'\n",0,list->inodes[0]);
		printf("8 Inodes list->inodes[1.%i]='0x%08X'\n",1,list->inodes[1]);
		printf("9 Inodes list->inodes[2.%i]='0x%08X'\n",2,list->inodes[2]);
		printf("10 Inodes list->inodes[3.%i]='0x%08X'\n",3,list->inodes[3]);
		//qsort(list->inodes,list->length,sizeof(*list->inodes),InodeNameComp);
		for (i=0;i<list->length;i++) {
			printf("11 Inodes list->inodes[%i]='0x%08X'\n",i,list->inodes[i]);
			if (list->inodes[i] != 0) {
				memset(s,0,1024);
				memcpy(s,list->inodes[i]->name->data,list->inodes[i]->name->length);
				printf("12 Inodes name[%i]='%s' length=%i\n",i,s,list->inodes[i]->name->length);
			}
			array_index = [self processInode: list->inodes[i] j: j];
			if (i == 0)
				[arrayIndex add: array_index];
		}
	} else if (list->nodes != NULL) {
		[arrayIndex add: list->nodes[0]];
	}

	inode->position = position;
	position++;
	inode->processed = true;
	return inode->position;
}

-(void *) data {
	//qsort(list,parent->list.position,sizeof(inode),InodeNameComp);
	struct inode_struct *inode_array;
	struct inode_struct *inode;
	struct entry_list *list;
	uint64_t i = 0;

	printf("Inodes data {\n");
	inode_array = (struct inode_struct *) inodes.data;
	for(i = 0;i<inodes.place;i++) {
		inode = &inode_array[i];
		if (inode->processed)
			continue;
		[self processInode: inode j: 0];
	}
	printf("} Inodes data\n\n");
	return NULL;
}

-(id) init {
	uint64_t len;
	struct inode_struct *inode;

	if (!(self = [super init]))
		return self;

	len = sizeof(struct inode_struct) * (acfg.max_nodes + 1);
	[self configureDataStruct: &inodes length: len];
	[self configureDataStruct: &data length: acfg.page_size * acfg.max_nodes];
	[self configureDataStruct: &cdata length: acfg.page_size * acfg.max_nodes];
	[self configureDataStruct: &symlink length: acfg.page_size];
	[self configureDataStruct: &inode_list length: acfg.max_nodes * sizeof(struct inode_struct *)];
	[self configureDataStruct: &node_list length: acfg.max_nodes * sizeof(uint64_t)];
	paths = [[Paths alloc] init];

	fileSizeIndex = [[ByteTable alloc] init];
	nameOffset = [[ByteTable alloc] init];
	numEntries = [[ByteTable alloc] init];
	modeIndex = [[ByteTable alloc] init];
	arrayIndex = [[ByteTable alloc] init];

	[fileSizeIndex numberEntries: acfg.max_number_files dedup: false];
	[nameOffset numberEntries: acfg.max_number_files dedup: false];
	[numEntries numberEntries: acfg.max_number_files dedup: false];
	[modeIndex numberEntries: acfg.max_number_files dedup: false];
	[arrayIndex numberEntries: acfg.max_number_files dedup: false];

	printf("\n\n\n");
	[self addInode: @""];
	printf("\n\n\n");
	return self;
}

-(void) free {
	[super free];

	free(inodes.data);
	free(data.data);
	free(cdata.data);
	free(symlink.data);
	free(inode_list.data);
	free(node_list.data);
}

@end

static int PathsComp(const void* av, const void* bv)
{
	struct paths_struct *a = (struct paths_struct *)av;
	struct paths_struct *b = (struct paths_struct *)bv;
	NSString *apath = (NSString *)a->inode->path;
	NSString *bpath = (NSString *)b->inode->path;
	int retval;

	NSComparisonResult res = [apath compare: bpath];

	switch (res) {
		case NSOrderedAscending:
			retval = 1;
			break;
		case NSOrderedSame:
			retval = 0;
			break;
		case NSOrderedDescending:
			retval = -1;
			break;
		default:
			retval = 1;
			break;
	}
	return retval;
}

@implementation Paths

-(struct paths_struct *) allocPathStruct {
	uint64_t d = sizeof(struct paths_struct);
	return (struct paths_struct *) [self allocData: &data chunksize: d];
}

-(uint64_t) hash: (struct paths_struct *) temp {
	NSString *apath;
	uint8_t *str;
	uint64_t len;
	uint8_t *strhash;
	uint64_t hash = 0;
	int i=0;
	int j=0;

	apath = (NSString *)temp->inode->path;
	str = (uint8_t *) [apath UTF8String];
	len = [apath length];
	strhash = (uint8_t *) &hash;

	while(i<len) {
		strhash[j] += str[i];
		j++;
		if (j>7)
			j = 0;
		i++;
	}

	hash = hash % hashlen;
	return hash;
}

-(void *) allocForAdd: (struct paths_struct *) temp {
	struct paths_struct *new_value;

	new_value = [self allocPathStruct];
	new_value->inode = temp->inode;
	return new_value;
}

-(void *) addPath: (struct inode_struct *) inode {
	struct paths_struct temp;
	struct paths_struct *new_value;
	struct paths_struct *list;
	uint64_t hash;

	memset(&temp,0,sizeof(temp));
	temp.inode = inode;

	hash = [self hash: &temp];

	if (hashtable[hash] == NULL) {
		new_value = [self allocForAdd: &temp];
		hashtable[hash] = new_value;
		return new_value;
	}

	list = hashtable[hash];
	while(true) {
		if (!PathsComp(list,&temp)) {
			return list;
		}
		if (list->next == NULL) {
			new_value = [self allocForAdd: &temp];
			list->next = new_value;
			return new_value;
		}
		list = list->next;
	}
}

-(void *) findParentInodeByPath: (NSString *) path {
	struct paths_struct temp;
	struct paths_struct *list;
	struct inode_struct inode;
	struct inode_struct *parent;
	uint64_t hash;

	memset(&temp,0,sizeof(temp));
	memset(&inode,0,sizeof(inode));
	inode.path = path;
	temp.inode = &inode;

	hash = [self hash: &temp];

	if (hashtable[hash] == NULL) {
		return NULL;
	}

	list = hashtable[hash];
	while(true) {
		if (!PathsComp(list,&temp)) {
			parent = list->inode;
			return parent;
		}
		if (list->next == NULL) {
			return NULL;
		}
		list = list->next;
	}
}

-(id) init {
	uint64_t len;
	hashlen = AXFS_PATHS_HASHTABLE_SIZE;
	if (!(self = [super init]))
		return self;

	len = sizeof(struct paths_struct) * (acfg.max_number_files + 1);
	[self configureDataStruct: &data length: len];

	return self;
}

-(void) free {
	[super free];
	free(data.data);
}

@end

