#include "ej1.h"

string_proc_list* string_proc_list_create(void){
	/* Crea una lista vacia */
	string_proc_list* list = (string_proc_list*)malloc(sizeof(string_proc_list));
	if(list == NULL){
		printf("Error: No se pudo crear la lista\n");
		return NULL;
	}
	list->first = NULL;
	list->last  = NULL;
	return list;
}

string_proc_node* string_proc_node_create(uint8_t type, char* hash){
	string_proc_node* node = (string_proc_node*)malloc(sizeof(string_proc_node));
	if(node == NULL){
		printf("Error: No se pudo crear el nodo\n");
		return NULL;
	}
	node->next= NULL;
	node->previous= NULL;
	node->type = type;
	node->hash = hash;
	return node;
}

void string_proc_list_add_node(string_proc_list* list, uint8_t type, char* hash){
	string_proc_node* node = string_proc_node_create(type, hash);
	if(node == NULL){
		printf("Error: No se pudo crear el nodo\n");
		return;
	}
	if(list->first == NULL){
		list->first = node;
		list->last  = node;
	}else{
		list->last->next = node;
		node->previous   = list->last;
		list->last      = node;
	}
}

char* string_proc_list_concat(string_proc_list* list, uint8_t type , char* hash){
	/*Genera un nuevo hash concatenando el pasado por parámetro con todos los hashes 
	de los nodos de la lista cuyos tipos coinciden con el pasado por parámetro 
	*/
	string_proc_node* current_node = list->first;
	char* new_hash = (char*)malloc(1);
	new_hash[0] = '\0';
	while(current_node != NULL){
		if(current_node->type == type){
			char* temp = str_concat(new_hash, current_node->hash);
			free(new_hash);
			new_hash = temp;
		}
		current_node = current_node->next;
	}
	if(hash != NULL){
		char* temp = str_concat(hash, new_hash);
		free(new_hash);
		new_hash = temp;
	}
	return new_hash;
}


/** AUX FUNCTIONS **/

void string_proc_list_destroy(string_proc_list* list){

	/* borro los nodos: */
	string_proc_node* current_node	= list->first;
	string_proc_node* next_node		= NULL;
	while(current_node != NULL){
		next_node = current_node->next;
		string_proc_node_destroy(current_node);
		current_node	= next_node;
	}
	/*borro la lista:*/
	list->first = NULL;
	list->last  = NULL;
	free(list);
}

void string_proc_node_destroy(string_proc_node* node){
	node->next      = NULL;
	node->previous	= NULL;
	node->hash		= NULL;
	node->type      = 0;			
	free(node);
}


char* str_concat(char* a, char* b) {
	int len1 = strlen(a);
    int len2 = strlen(b);
	int totalLength = len1 + len2;
    char *result = (char *)malloc(totalLength + 1); 
    strcpy(result, a);
    strcat(result, b);
    return result;  
}

void string_proc_list_print(string_proc_list* list, FILE* file){
        uint32_t length = 0;
        string_proc_node* current_node  = list->first;
        while(current_node != NULL){
                length++;
                current_node = current_node->next;
        }
        fprintf( file, "List length: %d\n", length );
		current_node    = list->first;
        while(current_node != NULL){
                fprintf(file, "\tnode hash: %s | type: %d\n", current_node->hash, current_node->type);
                current_node = current_node->next;
        }
}

