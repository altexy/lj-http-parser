--------------------------------------------------------------------------------

local ffi = require 'ffi'

--------------------------------------------------------------------------------

local core = ffi.load("lj_http_parser")

--------------------------------------------------------------------------------

ffi.cdef [[
// from http_parser.h

typedef struct http_parser http_parser;
typedef struct http_parser_settings http_parser_settings;

struct http_parser {
  /** PRIVATE **/
  unsigned char type : 2;     /* enum http_parser_type */
  unsigned char flags : 6;    /* F_* values from 'flags' enum; semi-public */
  unsigned char state;        /* enum state from http_parser.c */
  unsigned char header_state; /* enum header_state from http_parser.c */
  unsigned char index;        /* index into current matcher */

  uint32_t nread;          /* # bytes read in various scenarios */
  uint64_t content_length; /* # bytes in body (0 if no Content-Length header) */

  /** READ-ONLY **/
  unsigned short http_major;
  unsigned short http_minor;
  unsigned short status_code; /* responses only */
  unsigned char method;       /* requests only */
  unsigned char http_errno : 7;

  /* 1 = Upgrade header was present and the parser has exited because of that.
   * 0 = No upgrade header present.
   * Should be checked when http_parser_execute() returns in addition to
   * error checking.
   */
  unsigned char upgrade : 1;

  /** PUBLIC **/
  void *data; /* A pointer to get hook to the "connection" or "socket" object */
};

// from lj_http_parser.h

typedef struct ljhp_buffer
{
  size_t size;
  const void* data;
}  ljhp_buffer;

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
]]

--------------------------------------------------------------------------------

return core
