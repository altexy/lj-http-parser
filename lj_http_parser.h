#ifndef LJ_HTTP_PARSER
#define LJ_HTTP_PARSER

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>
#include <stdint.h>
#include "http_parser.h"
// because http_parser is C99 - we too

typedef struct ljhp_buffer
{
  size_t size;
  const void* data;
}  ljhp_buffer;

// don't expose enums for LuaJit FFI
// constants is faster and transparent
const int LJHP_HEADER_ENTRY_FIELD = 1;
const int LJHP_HEADER_ENTRY_VALUE = 2;

typedef struct ljhp_header_entry
{
  int type;
  ljhp_buffer value;
  struct ljhp_header_entry* next;
} ljhp_header_entry;

typedef struct ljhp_body_entry
{
  ljhp_buffer value;
  struct ljhp_body_entry* next;
} ljhp_body_entry;

typedef struct ljhp_http_parser
{
  http_parser http_parser_;
  http_parser_settings* http_parser_settings_; 

  ljhp_buffer url;

  ljhp_header_entry* first;
  ljhp_header_entry* last;
  
  ljhp_body_entry* first_body;
  ljhp_body_entry* last_body;

  int32_t status_complete;
  int32_t headers_complete;
  int32_t message_complete;
} ljhp_http_parser;

ljhp_http_parser* ljhp_create_request_parser();
ljhp_http_parser* ljhp_create_response_parser();
void ljhp_http_parser_reset(ljhp_http_parser* parser);
void ljhp_http_parser_destroy(ljhp_http_parser* parser);

size_t ljhp_http_parser_execute(
    ljhp_http_parser *parser,
    const char *data,
    size_t len
  );
#ifdef __cplusplus
}
#endif

#endif