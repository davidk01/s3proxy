#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# This should point at nginx
backend default {
  .host = "127.0.0.1";
  .port = "8080";
}

# This should point at s3proxy
backend s3proxy {
  .host = "127.0.0.1";
  .port = "9292";
}

# Try nginx first, if that fails try s3proxy, if that fails 
sub vcl_recv {
  if (req.method != "GET" && req.method != "HEAD") {
    set req.backend_hint = s3proxy;
    return (pass);
  }
  if (req.restarts == 0) {
    set req.backend_hint = default;
  } elsif (req.restarts == 1) {
    set req.backend_hint = s3proxy;
    set req.hash_always_miss = true;
  }
}

sub vcl_deliver {
  if (resp.status == 404 && resp.http.Server ~ "nginx") {
    return (restart);
  }
}
