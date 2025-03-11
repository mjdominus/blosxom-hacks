#
# Blosxom configuration for layout-tinkering.plover.com
#

# --- Configurable variables -----

# What's this blog's title?
$blog_title = "Tinkering";

# What's this blog's description (for outgoing RSS feed)?
$blog_description = "Tinkering";

# What's this blog's primary language (for outgoing RSS feed)?
$blog_language = "en";

# Where are this blog's entries kept?
$datadir = "/home/mjd/misc/blog/layout-tinkering";

# Root of the picture directory
$picdir = "/home/mjd/public_html/pictures/blog";

# What's my preferred base URL for this blog (leave blank for automatic)?
$url = "https://blog-tinkering.plover.com/";

# Should I stick only to the datadir for items or travel down the
# directory hierarchy looking for items?  If so, to what depth?
# 0 = infinite depth (aka grab everything), 1 = datadir only, n = n levels down
$depth = 0;

# How many entries should I show on the home page?
$num_entries = 25;

# What file extension signifies a blosxom entry?
$file_extension = "blog";

# What is the default flavour?
$default_flavour = "html";

# Should I show entries from the future (i.e. dated after now)?
$show_future_entries = 0;

# --- Plugins (Optional) -----

# Where are my plugins kept?
$plugin_dir = "/home/mjd/src/perl/blosxom/plugins";

# Where should my modules keep their state information?
$plugin_state_dir = "$plugin_dir/state/layout-tinkering";

# --- Static Rendering -----

# Where are this blog's static files to be created?
$static_dir = "/home/mjd/misc/blog/static/layout-tinkering";

# What's my administrative password (you must set this for static rendering)?
$static_password = "blurfl";

# What flavours should I generate statically?
@static_flavours = qw/html rss atom/;

# Should I statically generate individual entries?
# 0 = no, 1 = yes
$static_entries = 1;

# When not overridden by the META section
# what is the default input language?
$default_input_format = 'markdown';

# Do posts here normally have a META section?
$usually_has_meta_section = 1;

# For path2 plugin: where should the browser look for images?
$path2::testmode_image_url = "https://plover.com/~mjd/pictures/blog";
$path2::production_image_url = "https://pic.blog.plover.com/shitpost";

$test_url = "https://blog-tinkering.plover.com/testblog/";

# Given just a filename, where might we like it placed?
sub dir_for_file {
    my ($f) = @_;
    my ($a) = ($f =~ /^(\w)/);
    return lc $a;
}

# This file contains defaults for templates that aren't overridden by plugins
$default_templates = "/home/mjd/src/blosxom/flexbox-templates";
