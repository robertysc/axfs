#include "header.h"
#include "stubs.h"
#include "CuTest.h"

/* Including function under test */
#include "nodes.h"
#include "nodes.m"
#include "pages.h"
#include "pages.m"
#include "compressor.h"
#include "compressor.m"

/****** Test Code ******/

struct axfs_config acfg;

static void Nodes_createdestroy(CuTest *tc)
{
	Nodes *nodes;
	int output;
	printf("Running %s\n", __FUNCTION__);
	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_XIP];
	[nodes free];
	[nodes release];

	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_BYTEALIGNED];
	[nodes free];
	[nodes release];

	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_COMPRESS];
	[nodes free];
	[nodes release];

	output = 0;
	CuAssertIntEquals(tc, 0, output);
}

static void Nodes_size_xip4k(CuTest *tc)
{
	Nodes *nodes;
	Pages *pages;
	uint64_t l = 4 * 1024;
	uint8_t *data0;
	uint8_t *data1;
	uint8_t *data2;
	uint8_t *data3;
	uint8_t *data4;
	void *output[5];
	uint8_t *compare;
	uint64_t length;
	uint64_t size;
	void *data;

	printf("Running %s\n", __FUNCTION__);
	acfg.page_size = l;
	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_XIP];

	pages = [[Pages alloc] init];
	[pages initialize];
	[pages numberPages: 100 path: "./tempfile"];

	data0 = malloc(l);
	memset(data0,5,l);
	output[0] = [pages addPage: data0 length: l];

	data1 = malloc(l);
	memset(data1,6,l);
	output[1] = [pages addPage: data1 length: l];

	data2 = malloc(l);
	memset(data2,7,l);
	output[2] = [pages addPage: data2 length: l];

	data3 = malloc(l);
	memset(data3,4,l);
	output[3] = [pages addPage: data3 length: 4000];

	data4 = malloc(l);
	memset(data4,5,l);
	output[4] = [pages addPage: data4 length: 500];

	[nodes addPage: output[0]];
	[nodes addPage: output[1]];
	[nodes addPage: output[2]];
	[nodes addPage: output[3]];
	[nodes addPage: output[4]];

	length = [nodes length];
    size = [nodes size];
 	CuAssertIntEquals(tc, 5, length);
	CuAssertIntEquals(tc, 4096*5, size);
	compare = malloc(size);
	memset(compare,0,size);
	memcpy(compare,data0,l);
	memcpy(compare+l,data1,l);
	memcpy(compare+(2*l),data2,l);
	memcpy(compare+(3*l),data3,4000);
	memcpy(compare+(4*l),data4,500);
	data = [nodes data];
	CuAssertBufEquals(tc, compare, data, size);

	[nodes free];
	[nodes release];
	[pages free];
	[pages release];
}

static void Nodes_cdata(CuTest *tc)
{
	Nodes *nodes;
	Pages *pages;
	uint64_t l = 4 * 1024;
	uint8_t data0[l];
	uint8_t data1[l];
	uint8_t data2[l];
	uint8_t data3[l];
	uint8_t data4[l];
	void *output[5];
	uint8_t *compare;
	uint64_t length, size, csize;
	void *data, *cdata;

	printf("Running %s\n", __FUNCTION__);
	acfg.page_size = l;

	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_XIP];
	pages = [[Pages alloc] init];
	[pages initialize];
	[pages numberPages: 100 path: "./tempfile"];

	memset(&data0,5,l);
	output[0] = [pages addPage: &data0 length: l];

	memset(&data1,6,l);
	output[1] = [pages addPage: &data1 length: l];

	memset(&data2,7,l);
	output[2] = [pages addPage: &data2 length: l];

	memset(&data3,4,l);
	output[3] = [pages addPage: &data3 length: 4000];

	memset(&data4,5,l);
	output[4] = [pages addPage: &data4 length: 500];

	[nodes addPage: output[0]];
	[nodes addPage: output[1]];
	[nodes addPage: output[2]];
	[nodes addPage: output[3]];
	[nodes addPage: output[4]];
	length = [nodes length];
    size = [nodes size];
 
	CuAssertIntEquals(tc, 5, length);
	CuAssertIntEquals(tc, 4096*5, size);
	compare = malloc(size);
	memcpy((void *)compare,(void *)&data0,l);
	memcpy(compare+l,&data1,l);
	memcpy(compare+(2*l),&data2,l);
	memcpy(compare+(3*l),&data3,4000);
	memcpy(compare+(4*l),&data4,500);

	data = [nodes data];
	CuAssertBufEquals(tc, compare, data, size);
	//printf("csize = %i  size = %i\n",[nodes csize],[nodes size]);

	cdata = [nodes cdata];
	csize = [nodes csize];
	CuAssertTrue(tc, csize <= size);
	CuAssertTrue(tc, csize > 0);

	[nodes free];
	[nodes release];
	[pages free];
	[pages release];
}

static void Nodes_size_xip64k(CuTest *tc)
{
	Nodes *nodes;
	Pages *pages;
	uint64_t l = 64 * 1024;
	uint8_t data0[l];
	uint8_t data1[l];
	uint8_t data2[l];
	uint8_t data3[l];
	uint8_t data4[l];
	void *output[5];
	uint8_t *compare;
	uint64_t length, size;
	void * data;

	printf("Running %s\n", __FUNCTION__);
	acfg.page_size = l;
	nodes = [[Nodes alloc] init];
	[nodes initialize];
	[nodes setType: TYPE_XIP];

	pages = [[Pages alloc] init];
	[pages initialize];
	[pages numberPages: 100 path: "./tempfile"];
	memset(&data0,5,l);
	output[0] = [pages addPage: &data0 length: l];

	memset(&data1,6,l);
	output[1] = [pages addPage: &data1 length: l];

	memset(&data2,7,l);
	output[2] = [pages addPage: &data2 length: l];

	memset(&data3,4,l);
	output[3] = [pages addPage: &data3 length: 4000];

	memset(&data4,5,l);
	output[4] = [pages addPage: &data4 length: 500];

	[nodes addPage: output[0]];
	[nodes addPage: output[1]];
	[nodes addPage: output[2]];
	[nodes addPage: output[3]];
	[nodes addPage: output[4]];

	length = [nodes length];
	size = [nodes size];

	CuAssertIntEquals(tc, 5, length);
	CuAssertIntEquals(tc, 64*1024*5, size);
	compare = malloc(size);
	memcpy(compare,&data0,l);
	memcpy(compare+l,&data1,l);
	memcpy(compare+(2*l),&data2,l);
	memcpy(compare+(3*l),&data3,4000);
	memcpy(compare+(4*l),&data4,500);
	data = [nodes data];
	CuAssertBufEquals(tc, compare, data, size);
	[nodes free];
	[nodes release];
	[pages free];
	[pages release];
}

/****** End Test Code ******/

static CuSuite* GetSuite(void){
	CuSuite* suite = CuSuiteNew();

	SUITE_ADD_TEST(suite, Nodes_createdestroy);
	SUITE_ADD_TEST(suite, Nodes_size_xip4k);
	SUITE_ADD_TEST(suite, Nodes_size_xip64k);
	SUITE_ADD_TEST(suite, Nodes_cdata);
	return suite;
}

void FreeSuite(CuSuite* suite)
{
	int i;
	for (i = 0 ; i < suite->count ; ++i)
	{
		if(suite->list[i] != NULL) {
			free((void*)suite->list[i]->name);
			free(suite->list[i]);
		} else
			suite->list[i] = 0;
	}
	free(suite);
}

void RunAllTests(void) 
{
	CuString *output = CuStringNew();
	CuSuite* suite = CuSuiteNew();
	CuSuite* newsuite = GetSuite();
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	CuSuiteAddSuite(suite, newsuite);
	CuSuiteRun(suite);
	
	CuSuiteSummary(suite, output);
	CuSuiteDetails(suite, output);
	printf("%s\n", output->buffer);
	FreeSuite(suite);
	free(newsuite);
	free(output->buffer);
	free(output);
	[pool drain];

	return;
}

