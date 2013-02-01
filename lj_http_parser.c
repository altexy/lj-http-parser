#include "lj_http_parser.h"
#include <stdlib.h>
#include <assert.h>
#include <string.h>

// only for use within on_message_* callbacks
#define LJHP_PARSER ((ljhp_http_parser*)parser->data)

int on_message_begin(http_parser* parser)
{
  return 0;
}

int on_url(http_parser* parser, const char *at, size_t length)
{
  LJHP_PARSER->url.data = at;
  LJHP_PARSER->url.size = length;
  return 0;
}

int on_status_complete(http_parser* parser)
{
  LJHP_PARSER->status_complete = 1;
  return 0;
}

int on_header_field(http_parser* parser, const char *at, size_t length)
{
  ljhp_header_entry *entry = malloc(sizeof(ljhp_header_entry));
  if( LJHP_PARSER->last )
  {
    LJHP_PARSER->last->next = entry;
  }
  entry->value.data = at;
  entry->value.size = length;
  entry->next = 0;
  entry->type = LJHP_HEADER_ENTRY_FIELD;
  LJHP_PARSER->last = entry;
  if( !LJHP_PARSER->first )
  {
    LJHP_PARSER->first = entry;
  }
  return 0;
}

int on_header_value(http_parser* parser, const char *at, size_t length)
{
  assert(LJHP_PARSER->first); 
  ljhp_header_entry *entry = malloc(sizeof(ljhp_header_entry));
  LJHP_PARSER->last->next = entry;
  entry->value.data = at;
  entry->value.size = length;
  entry->next = 0;
  entry->type = LJHP_HEADER_ENTRY_VALUE;
  LJHP_PARSER->last = entry;
  return 0;
}

int on_headers_complete(http_parser* parser)
{
  LJHP_PARSER->headers_complete = 1;
  return 0;
}

int on_body(http_parser* parser, const char *at, size_t length)
{
  ljhp_body_entry *entry = malloc(sizeof(ljhp_body_entry));
  LJHP_PARSER->last_body->next = entry;
  entry->value.data = at;
  entry->value.size = length;
  entry->next = 0;
  LJHP_PARSER->last_body = entry;
  if( !LJHP_PARSER->first_body )
  {
    LJHP_PARSER->first_body = entry;
  }
  return 0;
}

int on_message_complete(http_parser* parser)
{
  LJHP_PARSER->message_complete = 1;
  return 0;
}

#undef PARSER

http_parser_settings callbacks =
{
  .on_message_begin = on_message_begin,
  .on_url = on_url,
  .on_status_complete = on_status_complete,
  .on_header_field = on_header_field,
  .on_header_value = on_header_value,
  .on_headers_complete = on_headers_complete,
  .on_body = on_body,
  .on_message_complete = on_message_complete
};

ljhp_http_parser* ljhp_http_parser_create(enum http_parser_type type)
{
  ljhp_http_parser *parser = malloc(sizeof(ljhp_http_parser));
  if( !parser )
  {
    return parser;
  }
  parser->http_parser_.data = parser;
  parser->http_parser_.type = type;
  parser->http_parser_settings_ = &callbacks;
  parser->last = 0;
  parser->first = 0;
  parser->last_body = 0;
  parser->first_body = 0;
  ljhp_http_parser_reset(parser);
  return parser;
}

ljhp_http_parser* ljhp_create_request_parser()
{
  return ljhp_http_parser_create(HTTP_REQUEST);
}

ljhp_http_parser* ljhp_create_response_parser()
{
  return ljhp_http_parser_create(HTTP_RESPONSE);
}

void ljhp_http_parser_reset(ljhp_http_parser* parser)
{
  http_parser_init(&parser->http_parser_, parser->http_parser_.type);
  parser->url.size = 0;
  parser->status_complete = 0;
  parser->headers_complete = 0;
  parser->message_complete = 0;

  ljhp_header_entry* h = parser->first;
  while( h )
  {
    ljhp_header_entry* tmp = h->next;
    free(h);
    h = tmp;
  }
  parser->last = 0;
  parser->first = 0;

  ljhp_body_entry* b = parser->first_body;
  while( h )
  {
    ljhp_body_entry* tmp = b->next;
    free(b);
    b = tmp;
  }
  parser->last_body = 0;
  parser->first_body = 0;
}

void ljhp_http_parser_destroy(ljhp_http_parser* parser)
{
  ljhp_http_parser_reset(parser);
  free(parser);
}

size_t ljhp_http_parser_execute(ljhp_http_parser *parser,
                           const char *data,
                           size_t len)
{
  return http_parser_execute(
      &parser->http_parser_,
      parser->http_parser_settings_,
      data, len
    );
}
