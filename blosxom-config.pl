package blosxom_config;

# Figure out which blog configuration to load, then load it
#
# Search order:
#  1. command-line option -blog-name
#  2. query parameter blog-name
#  3. SERVERNAME
#  4. Default: 'blog'

use CGI qw/:standard :netscape/;
open F, ">", "/tmp/blosxom-config-$>";
$main::default_blog_name='blog';

sub load_config {
    # CGI.pm makes this work in both command-line and web mode
    my $blog_name = shift() // param('-blog-name');
    if (!$blog_name and $ENV{SERVER_NAME}) {
	($blog_name) = $ENV{SERVER_NAME} =~ /\A ([\w-]+) /x;
    }
    $blog_name ||= $main::default_blog_name;

    print F "Selected blog configuration '$blog_name'\n";
    print F "SERVERNAME = '$ENV{SERVER_NAME}'\n";
    { package blosxom;
      require "blosxom-config/$blog_name.pl";
      if ($blog_title && $datadir) {
	  print blosxom_config::F "Loaded config for '$blog_title' ($datadir)\n";
      } else {
	  die "Didn't get expected configuration from $blog_name.pl";
      }
    }
    return 1;
}

