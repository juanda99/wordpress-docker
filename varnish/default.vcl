vcl 4.0;
# Based on: https://github.com/mattiasgeniar/varnish-4.0-configuration-templates/blob/master/
import std;
import directors;

backend server1 { # Define one backend
  .host = "{VARNISH_BACKEND_HOST}";
  .port = "{VARNISH_BACKEND_PORT}";
  .max_connections = 400; # That's it

  .probe = {
    #.url = "/"; # short easy way (GET /)
    # We prefer to only do a HEAD /
    .request =
      "HEAD / HTTP/1.1"
      "Host: arasaac"
      "Connection: close"
      "User-Agent: Varnish Health Probe";

    .interval  = 5s; # check the health of each backend every 5 seconds
    .timeout   = 3s; # timing out after 1 second.
    .window    = 5;  # If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
    .threshold = 3;
  }

  #.first_byte_timeout     = 3s;   # How long to wait before we receive a first byte from our backend?
  .first_byte_timeout     = 5s;   # How long to wait before we receive a first byte from our backend?
  .connect_timeout        = 5s;     # How long to wait for a backend connection?
  .between_bytes_timeout  = 5s;     # How long to wait between bytes received from our backend?
  #.between_bytes_timeout  = 2s;     # How long to wait between bytes received from our backend?
}

#acl purge {
  # ACL we'll use later to allow purges
#  "localhost";
#  "127.0.0.1";
#  "::1";
#}

sub vcl_init {
  # Called when VCL is loaded, before any requests pass through it.
  # Typically used to initialize VMODs.

  new vdir = directors.round_robin();
  vdir.add_backend(server1);
  # vdir.add_backend(server...);
  # vdir.add_backend(servern);
}

sub vcl_recv {
  set req.backend_hint = vdir.backend(); # send all traffic to the vdir director

  # Normalize the header, remove the port (in case you're testing this on various TCP ports)
  set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

  # Remove the proxy header (see https://httpoxy.org/#mitigate-varnish)
  unset req.http.proxy;

  # when purging from php files, we need to send the request to varnish but process it as it were arasaac web server
  if ( req.http.host ~ "varnish" ) {
     set req.http.x-host = req.http.host;
     set req.http.host = "www.arasaac.org";
  }


  if (req.http.host ~ "^arasaac.org" || req.http.host ~ "arasaac.net" || req.http.host ~ "arasaac.es" ) {
     return (synth (750, ""));
  }
  if (req.url~ "^/index.php") {
    set req.url = regsub(req.url, "index.php", "");
  } 

  # Allow purging
  if (req.method == "PURGE") {
#    if (!client.ip ~ purge) { # purge is the ACL defined at the begining
      # Not from an allowed IP? Then die with an error.
#      return (synth(405, "This IP is not allowed to send PURGE requests."));
#    }
    # If you got this stage (and didn't error out above), purge the cached result
    return (purge);
  }
  if (req.method == "BAN")
  {
    // TODO: Add client validation as needed
    ban("obj.http.x-url ~ " + req.url);
    return(synth(901, "BAN Set for " + req.url));
  }
  
  #administration staff without cache  
  if (req.url ~ "inc" || req.url ~ "languages" || req.url ~ "gestionar_internacionalizacion.php" || req.url ~ "server-status") {
     return (pass);
  }

  # Only deal with "normal" types
  if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "PATCH" &&
      req.method != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }

  # Implementing websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
  if (req.http.Upgrade ~ "(?i)websocket") {
    return (pipe);
  }

  # Only cache GET or HEAD requests. This makes sure the POST requests are always passed.
  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }


  set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

  # Remove any Google Analytics based cookies
  set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
  set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");



 #  Remove Arasaac Cookies for caching:

    if (!(req.url ~ "product_id" || req.url ~ "n_elementos_cesto.php" || req.url ~ "herramientas" || req.url ~ "zip_cesto.php" || req.url ~ "carpeta_trabajo.php" || req.url ~ "admin.php" || req.url ~ "cesta.php")) {
        set req.http.Cookie = regsuball(req.http.Cookie, "PHPSESSID=[^;]+(; )?", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "preImg=x; ", "");
        set req.http.Cookie = regsuball(req.http.Cookie, "; ", ";");

    if (!(req.http.Cookie ~ "selected_language")) {
        if (req.http.Accept-Language ~ "^en") {
            set req.http.Cookie = "selected_language=en;";
        } elsif (req.http.Accept-Language ~ "^es") {
            set req.http.Cookie = "selected_language=es;";
        } elsif (req.http.Accept-Language ~ "^fr") {
            set req.http.Cookie = "selected_language=fr;";
        } elsif (req.http.Accept-Language ~ "^ro") {
            set req.http.Cookie = "selected_language=ro;";
        } elsif (req.http.Accept-Language ~ "^pt") {
            set req.http.Cookie = "selected_language=pt;";
        } elsif (req.http.Accept-Language ~ "^br") {
            set req.http.Cookie = "selected_language=br;";
        } else {
            # unknown language. Remove the accept-language header and
            # use the backend default.
            set req.http.Cookie = "selected_language=en;";
        }
    }
  }
  
  #unset req.http.cookie;  
  # Remove DoubleClick offensive cookies
  set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");

  # Remove the Quant Capital cookies (added by some plugin, all __qca)
  set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

  # Remove the AddThis cookies
  set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");

  # Remove a ";" prefix in the cookie if present
  set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");

  # Are there cookies left with only spaces or that are empty?
  if (req.http.Cookie ~ "^\s*$") {
    unset req.http.Cookie;
  }

  # Remove all cookies for static files
  # A valid discussion could be held on this line: do you really need to cache static files that don't cause load? Only if you have memory left.
  # Sure, there's disk I/O, but chances are your OS will already have these files in their buffers (thus memory).
  # Before you blindly enable this, have a read here: https://ma.ttias.be/stop-caching-static-files/
  if (req.url ~ "^[^?]*\.(avi|bmp|css|csv|doc|docx|flac|flv|gif|ico|jpeg|jpg|js|mov|mp3|mp4|mpeg|mpg|odt|otf|ogg|ogm|opus|pdf|png|ppt|pptx|rtf|svg|svgz|swf|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz)(\?.*)?$") {
    unset req.http.Cookie;
    #return (pass);
  }
  if (req.url ~ "^[^?]*\.(7z|bz2|eot|gz|less|rar|tar|tbz|tgz|zip)(\?.*)?$") {
    #unset req.http.Cookie;
    return (pass);
  }
  
  #at the end because I need to remove previous cookies  
  #if (req.url ~ "purge.php") {
  #   return (pass);
  #}

  return (hash);
}

sub vcl_pipe {
  # Called upon entering pipe mode.
  # In this mode, the request is passed on to the backend, and any further data from both the client
  # and backend is passed on unaltered until either end closes the connection. Basically, Varnish will
  # degrade into a simple TCP proxy, shuffling bytes back and forth. For a connection in pipe mode,
  # no other VCL subroutine will ever get called after vcl_pipe.

  # Note that only the first request to the backend will have
  # X-Forwarded-For set.  If you use X-Forwarded-For and want to
  # have it set for all requests, make sure to have:
  # set bereq.http.connection = "close";
  # here.  It is not set by default as it might break some broken web
  # applications, like IIS with NTLM authentication.

  # set bereq.http.Connection = "Close";

  # Implementing websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
  if (req.http.upgrade) {
    set bereq.http.upgrade = req.http.upgrade;
  }

  return (pipe);
}

sub vcl_pass {
  # Called upon entering pass mode. In this mode, the request is passed on to the backend, and the
  # backend's response is passed on to the client, but is not entered into the cache. Subsequent
  # requests submitted over the same client connection are handled normally.

  # return (pass);
}

# The data on which the hashing will take place
sub vcl_hash {
  # Called after vcl_recv to create a hash value for the request. This is used as a key
  # to look up the object in Varnish.

  hash_data(req.url);

  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }

  # hash cookies for requests that have them
#    if (req.http.Language) {
        #add cookie in hash
#        hash_data(req.http.Language);
#    }
  if (req.http.Cookie) {
    hash_data(req.http.Cookie);
  }
 #for debugging hash 
 #std.log("######################################################################################################");
 #std.log(req.http.Cookie + req.http.host + req.url);

}

sub vcl_hit {
  # Called when a cache lookup is successful.

  if (obj.ttl >= 0s) {
    # A pure unadultered hit, deliver it
    return (deliver);
  }

  # https://www.varnish-cache.org/docs/trunk/users-guide/vcl-grace.html
  # When several clients are requesting the same page Varnish will send one request to the backend and place the others on hold while fetching one copy from the backend. In some products this is called request coalescing and Varnish does this automatically.
  # If you are serving thousands of hits per second the queue of waiting requests can get huge. There are two potential problems - one is a thundering herd problem - suddenly releasing a thousand threads to serve content might send the load sky high. Secondly - nobody likes to wait. To deal with this we can instruct Varnish to keep the objects in cache beyond their TTL and to serve the waiting requests somewhat stale content.

# if (!std.healthy(req.backend_hint) && (obj.ttl + obj.grace > 0s)) {
#   return (deliver);
# } else {
#   return (fetch);
# }

  # We have no fresh fish. Lets look at the stale ones.
  if (std.healthy(req.backend_hint)) {
    # Backend is healthy. Limit age to 10s.
    if (obj.ttl + 10s > 0s) {
      #set req.http.grace = "normal(limited)";
      return (deliver);
    } else {
      # No candidate for grace. Fetch a fresh object.
      return(fetch);
    }
  } else {
    # backend is sick - use full grace
      if (obj.ttl + obj.grace > 0s) {
      #set req.http.grace = "full";
      return (deliver);
    } else {
      # no graced object.
      return (fetch);
    }
  }

  # fetch & deliver once we get the result
  return (fetch); # Dead code, keep as a safeguard
}

sub vcl_miss {
  # Called after a cache lookup if the requested document was not found in the cache. Its purpose
  # is to decide whether or not to attempt to retrieve the document from the backend, and which
  # backend to use.

  return (fetch);
}

# Handle the HTTP request coming from our backend
sub vcl_backend_response {
  # Called after the response headers has been successfully retrieved from the backend.

  # Pause ESI request and remove Surrogate-Control header
  if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
    unset beresp.http.Surrogate-Control;
    set beresp.do_esi = true;
  }

  # Enable cache for all static files
  # The same argument as the static caches from above: monitor your cache size, if you get data nuked out of it, consider giving up the static file cache.
  # Before you blindly enable this, have a read here: https://ma.ttias.be/stop-caching-static-files/
  #if (bereq.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|otf|ogg|ogm|opus|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
  #  unset beresp.http.set-cookie;
  #}
  
   if (bereq.url ~ "^/$") {
    # en firefox a veces se cacheaba al cambiar el lenguaje dando datos erroneos
    set beresp.ttl = 86400s;
    set beresp.http.cache-control = "public, max-age = 0";
    unset beresp.http.set-cookie;
    return(deliver);
  }
  if (bereq.url ~ "^[^?]*\.(7z|bz2|eot|gz|less|rar|tar|tbz|tgz|zip)(\?.*)?$") {
    set beresp.http.cache-control = "public, max-age = 86400";
    unset beresp.http.Cookie;
    return (deliver);
  }

  if (bereq.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|otf|ogg|ogm|opus|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
    unset beresp.http.Cookie;
    set beresp.http.cache-control = "public, max-age = 86400";
    return (deliver);
  }
 
  #if (!(bereq.url ~ "language_set.php" || bereq.url ~ "cesta.php" || bereq.url ~ "pictogramas_color.php" || bereq.url ~ "pictogramas_byn.php"|| bereq.url ~ "imagenes.php" || bereq.url ~ "videos_lse.php" || bereq.url ~ "signos_lse_color.php" || bereq.url ~ "buscar.php" || bereq.url ~ "n_elementos_cesto.php" || bereq.url ~ "herramientas" || bereq.url ~ "zip_cesto.php" || bereq.url ~ "carpeta_trabajo.php" || bereq.url ~ "admin.php")) {

  if (!(bereq.url ~ "language_set.php" || bereq.url ~ "product_id" || bereq.url ~ "n_elementos_cesto.php" || bereq.url ~ "herramientas" || bereq.url ~ "zip_cesto.php" || bereq.url ~ "carpeta_trabajo.php" || bereq.url ~ "admin.php" || bereq.url  ~ "inc" || bereq.url  ~ "cesta.php" )) {
        set beresp.ttl = 86400s;
        set beresp.http.cache-control = "public, max-age = 300";
        #set beresp.http.log = "ha entrado aquí";
        #set beresp.http.X-CacheReason = "varnishcache";
        unset beresp.http.set-cookie;
        return(deliver);
  }
  

  # Large static files are delivered directly to the end-user without
  # waiting for Varnish to fully read the file first.
  # Varnish 4 fully supports Streaming, so use streaming here to avoid locking.
  if (bereq.url ~ "^[^?]*\.(7z|avi|bz2|flac|flv|gz|mka|mkv|mov|mp3|mp4|mpeg|mpg|ogg|ogm|opus|rar|tar|tgz|tbz|txz|wav|webm|xz|zip)(\?.*)?$") {
    unset beresp.http.set-cookie;
    set beresp.do_stream = true;  # Check memory usage it'll grow in fetch_chunksize blocks (128k by default) if the backend doesn't send a Content-Length header, so only enable it for big objects
  }

  # Sometimes, a 301 or 302 redirect formed via Apache's mod_rewrite can mess with the HTTP port that is being passed along.
  # This often happens with simple rewrite rules in a scenario where Varnish runs on :80 and Apache on :8080 on the same box.
  # A redirect can then often redirect the end-user to a URL on :8080, where it should be :80.
  # This may need finetuning on your setup.
  #
  # To prevent accidental replace, we only filter the 301/302 redirects for now.
  if (beresp.status == 301 || beresp.status == 302) {
    set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
  }

  # Set 2min cache if unset for static files
  if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
    set beresp.ttl = 120s; # Important, you shouldn't rely on this, SET YOUR HEADERS in the backend
    set beresp.uncacheable = true;
    return (deliver);
  }

  # Don't cache 50x responses
  if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503 || beresp.status == 504) {
    return (abandon);
  }

  # Allow stale content, in case the backend goes down.
  # make Varnish keep all objects for 6 hours beyond their TTL
  set beresp.grace = 6h;

  return (deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
  # Called before a cached object is delivered to the client.

  if (obj.hits > 0) { # Add debug header to see if it's a HIT/MISS and the number of hits, disable when not needed
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }

  # Please note that obj.hits behaviour changed in 4.0, now it counts per objecthead, not per object
  # and obj.hits may not be reset in some cases where bans are in use. See bug 1492 for details.
  # So take hits with a grain of salt
  set resp.http.X-Cache-Hits = obj.hits;

  # Remove some headers: PHP version
  unset resp.http.X-Powered-By;

  # Remove some headers: Apache version & OS
  unset resp.http.Server;
  unset resp.http.X-Drupal-Cache;
  unset resp.http.X-Varnish;
  unset resp.http.Via;
  unset resp.http.Link;
  unset resp.http.X-Generator;

  return (deliver);
}

sub vcl_purge {
  # Only handle actual PURGE HTTP methods, everything else is discarded
  if (req.method != "PURGE") {
    # restart request
    set req.http.X-Purge = "Yes";
    return(restart);
  }
}

sub vcl_synth {
  if (resp.status == 720) {
    # We use this special error status 720 to force redirects with 301 (permanent) redirects
    # To use this, call the following from anywhere in vcl_recv: return (synth(720, "http://host/new.html"));
    set resp.http.Location = resp.reason;
    set resp.status = 301;
    return (deliver);
  } elseif (resp.status == 721) {
    # And we use error status 721 to force redirects with a 302 (temporary) redirect
    # To use this, call the following from anywhere in vcl_recv: return (synth(720, "http://host/new.html"));
    set resp.http.Location = resp.reason;
    set resp.status = 302;
    return (deliver);
  } elseif (resp.status == 750) {
     set resp.status = 301;
     set resp.http.Location = "http://www.arasaac.org" + req.url;
     return(deliver);
    }

  return (deliver);
}


sub vcl_fini {
  # Called when VCL is discarded only after all requests have exited the VCL.
  # Typically used to clean up VMODs.

  return (ok);
}
