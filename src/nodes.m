#import "nodes.h"

@implementation Nodes

-(uint64_t) addPage: (void *) page {
	pages[place] = (struct page_struct *) page;
	place += 1;
	cached = false;
	ccached = false;
	return place-1;
}

-(void *) data {
	uint64_t i;
	struct page_struct *page;
	uint8_t *bd = data;

	if(cached) {
		return data;
	}
	cached = true;
	ccached = false;
	size = 0;
	for(i=0;i<place;i++) {
		page = pages[i];
		if (type == TYPE_XIP) {
			memcpy(page->data, bd, page->length);
			memset(bd + page->length, 0, acfg.page_size - page->length);
			size += acfg.page_size;
			bd += acfg.page_size;
		} else if (type == TYPE_BYTEALIGNED) {
			memcpy(page->data, bd, page->length);
			size += page->length;
			bd += page->length;
		} else if (type == TYPE_COMPRESS) {
		}
	}

	return data;
}

-(uint64_t) size {
	if(!cached) {
		[self data];
	}
	return size;
}

-(void *) cdata {
	Compressor * compressor;
	if(ccached)
		return cdata;
	compressor = [[Compressor alloc] init];
	[compressor initialize];
	[compressor algorithm: acfg.compression];
	[compressor cdata: cdata csize: &csize data: [self data] size: [self size]];
	[compressor free];
	[compressor release];
	ccached = true;
	return cdata;
}

-(uint64_t) csize {
	if(!ccached)
		[self cdata];
	return csize;
}

-(uint64_t) length {
	return place;
}

-(void) initialize {
	pages = malloc(sizeof(*pages)*acfg.max_nodes);
	memset(pages,0,sizeof(*pages)*acfg.max_nodes);
	data = malloc(sizeof(struct axfs_node)*acfg.max_nodes);
	memset(data,0,sizeof(struct axfs_node)*acfg.max_nodes);
}

-(void) setType: (int) t {
	type = t;
}

-(void) free {
	free(pages);
	free(data);
	free(cdata);
	free(cdata_partials);
}

@end

