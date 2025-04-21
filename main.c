#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(){
    char *json;
    void *json_vp = (void *)&json;

	*(char **)json_vp = malloc(6);
	strcpy(*(char **)json_vp, "TEST\n");

	printf("json_vp: %s", *(char **)json_vp);
	printf("json: %s", json);
}
