#!/usr/bin/perl

# Blosxom
# Author: Rael Dornfest <rael@oreilly.com>
# Version: 2.0
# Home/Docs/Licensing: http://www.raelity.org/apps/blosxom/

package blosxom;

use lib '/home/mjd/src/blosxom';
require 'blosxom-config.pl';
blosxom_config::load_config();

# --------------------------------

use vars qw! $version $blog_title $blog_description $blog_language $datadir $url %template $template $depth $num_entries $file_extension $default_flavour $static_or_dynamic $plugin_dir $plugin_state_dir @plugins %plugins $static_dir $static_password @static_flavours $static_entries $path_info $path_info_yr $path_info_mo $path_info_da $path_info_mo_num $flavour $static_or_dynamic %month2num @num2month $interpolate $entries $output $header $show_future_entries %files %indexes %others $page_title $default_input_format $default_templates $redirect_meta_header!;

open DIAGNOSIS, ">", "/tmp/warnstdout";
#{ my $ofh = select DIAGNOSIS;
#  $| = 1;
#  select $ofh;
#}
#tie $output, 'varwatch', \*DIAGNOSIS or die;

use strict;
use FileHandle;
use File::Find;
use File::stat;
use Digest::SHA1;
use Time::localtime;
use CGI qw/:standard :netscape/;
use POSIX ('strftime');

$version = "2.0";

my $fh = new FileHandle;

%month2num = (nil=>'00', Jan=>'01', Feb=>'02', Mar=>'03', Apr=>'04', May=>'05', Jun=>'06', Jul=>'07', Aug=>'08', Sep=>'09', Oct=>'10', Nov=>'11', Dec=>'12');
@num2month = sort { $month2num{$a} <=> $month2num{$b} } keys %month2num;

# Use the stated preferred URL or figure it out automatically
$url ||= url();
$url =~ s/^included:/http:/; # Fix for Server Side Includes (SSI)
$url =~ s!/$!!;

# Drop ending any / from dir settings
$datadir =~ s!/$!!; $plugin_dir =~ s!/$!!; $static_dir =~ s!/$!!;
  
# Fix depth to take into account datadir's path
$depth and $depth += ($datadir =~ tr[/][]) - 1;

# Global variable to be used in head/foot.{flavour} templates
$path_info = '';

$static_or_dynamic = (!$ENV{GATEWAY_INTERFACE} and param('-password') and $static_password and param('-password') eq $static_password) ? 'static' : 'dynamic';
$static_or_dynamic eq 'dynamic' and param(-name=>'-quiet', -value=>1);

# Path Info Magic
# Take a gander at HTTP's PATH_INFO for optional blog name, archive yr/mo/day
my @path_info = split m{/}, path_info() || param('path'); 
shift @path_info;

while ($path_info[0] and $path_info[0] =~ /^[a-zA-Z].*$/ and $path_info[0] !~ /(.*)\.(.*)/) { $path_info .= '/' . shift @path_info; }

# Flavour specified by ?flav={flav} or index.{flav}
$flavour = '';

if ( $path_info[$#path_info] =~ /(.+)\.(.+)$/ ) {
  $flavour = $2;
  $1 ne 'index' and $path_info .= "/$1.$2";
  pop @path_info;
} else {
  $flavour = param('flav') || $default_flavour;
}
# Fix XSS in flavour name (CVE-2008-2236)
# Copied from Blosxom 2.1.2, 2018-10-29 MJD.
html_escape($flavour);
sub html_escape {
    my %esc = ('<' => "lt", '>' => "gt", '&' => "amp",
	       q{'} => "apos", q{"} => "quot" );
    for (@_) {
	s/([<>&'"])/&$esc{$1};/g;
    }
}

# Strip spurious slashes
$path_info =~ s!(^/*)|(/*$)!!g;

# Date fiddling
($path_info_yr,$path_info_mo,$path_info_da) = @path_info;
$path_info_mo_num = $path_info_mo ? ( $path_info_mo =~ /\d{2}/ ? $path_info_mo:  ($month2num{ucfirst(lc $path_info_mo)} || undef) ) : undef;

# Define standard template subroutine, plugin-overridable at Plugins: Template
$template = 
  sub {
    my ($path, $chunk, $flavour) = @_;

    do {
      return join '', <$fh> if $fh->open("< $datadir/$path/$chunk.$flavour");
    } while ($path =~ s/(\/*[^\/]*)$// and $1);

    return join '', ($template{$flavour}{$chunk} || $template{error}{$chunk} || '');
  };
# Bring in the templates
%template = ();

{ my ($TMPL);
  unless (open $TMPL, "<", $default_templates) {
      die "Couldn't open default template file '$default_templates': $!";
  }

  while (<$TMPL>) {
      last if /^(__END__)?$/;
      my($ct, $comp, $txt) = /^(\S+)\s(\S+)\s(.*)$/;
      $txt =~ s/\\n/\n/mg;
      $template{$ct}{$comp} = $txt;
  }
  close $TMPL;
}

# Plugins: Start
if ( $plugin_dir and opendir PLUGINS, $plugin_dir ) {
  foreach my $plugin ( grep { /^\w+$/ && -f "$plugin_dir/$_"  } sort readdir(PLUGINS) ) {
    my($plugin_name, $off) = $plugin =~ /^\d*(\w+?)(_?)$/;
    my $on_off = $off eq '_' ? -1 : 1;
    require "$plugin_dir/$plugin";
    $plugin_name->start($plugin_name) and ( $plugins{$plugin_name} = $on_off ) and push @plugins, $plugin_name;
  }
  closedir PLUGINS;
}

# Plugins: Template
# Allow for the first encountered plugin::template subroutine to override the
# default built-in template subroutine
my $tmp; foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('template') and defined($tmp = $plugin->template()) and $template = $tmp and last; }

# Provide backward compatibility for Blosxom < 2.0rc1 plug-ins
sub load_template {
  return &$template(@_);
}

my %dates;
sub timeof {
  my $f = shift;
#  return $dates{$f} = stat($f)->mtime;
  unless (%dates) {
    open my($D), "<", "$plugin_state_dir/dates" or return stat($f)->mtime;
    local $_;
    while (<$D>) {
      chomp;
      my ($d, $f) = split /\s+/, $_, 2;
      $dates{$f} = $d;
    }
  }
  return $dates{$f} if exists $dates{$f};
  return $dates{$f} = stat($f)->mtime;
}

# Define default find subroutine
$entries =
  sub {
    my(%files, %indexes, %others);
    find(
      sub {
        my $d; 
        my $curr_depth = $File::Find::dir =~ tr[/][]; 
        return if $depth and $curr_depth > $depth; 
        return if $File::Find::dir =~ m{/CVS$};

        if ( 
          # a match
          $File::Find::name =~ m!^$datadir/(?:(.*)/)?(.+)\.$file_extension$!
          # not an index, .file, and is readable
          and $2 ne 'index' and $2 !~ /^\./ and (-r $File::Find::name)
        ) {

            # to show or not to show future entries
            ( 
              $show_future_entries
              or timeof($File::Find::name) < time 
            )
             and print F "before $File::Find::name\n"
              # add the file and its associated mtime to the list of files
              and $files{$File::Find::name} = timeof($File::Find::name)
             and print F "after\n"

                # static rendering bits
                and (
                  param('-all') 
                  or !-f "$static_dir/$1/index." . $static_flavours[0]
                  or timeof("$static_dir/$1/index." . $static_flavours[0]) < stat($File::Find::name)->mtime
                )
                  and $indexes{$1} = 1
                    and $d = join('/', (nice_date($files{$File::Find::name}))[5,2,3])
  
                      and $indexes{$d} = $d
                        and $static_entries and $indexes{ ($1 ? "$1/" : '') . "$2.$file_extension" } = 1

            } 
            else {
              !-d $File::Find::name and -r $File::Find::name and $others{$File::Find::name} = timeof($File::Find::name)
            }
      }, $datadir
    );

    return (\%files, \%indexes, \%others);
  };

# Plugins: Entries
# Allow for the first encountered plugin::entries subroutine to override the
# default built-in entries subroutine
my $tmp; foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('entries') and defined($tmp = $plugin->entries()) and $entries = $tmp and last; }

my ($files, $indexes, $others) = &$entries();
%files = %$files; %indexes = %$indexes; %others = ref $others ? %$others : ();

# Plugins: Filter
foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('filter') and $entries = $plugin->filter(\%files, \%others) }

# Static
if (!$ENV{GATEWAY_INTERFACE} and param('-password') and $static_password and param('-password') eq $static_password) {

  param('-quiet') or print "Blosxom is generating static index pages...\n";

  # Home Page and Directory Indexes
  my %done;
  foreach my $path ( sort keys %indexes) {
    my $p = '';
    foreach ( ('', split /\//, $path) ) {
      $p .= "/$_";
      $p =~ s!^/!!;
      $path_info = $p;
      $done{$p}++ and next;
      (-d "$static_dir/$p" or $p =~ /\.$file_extension$/) or mkdir "$static_dir/$p", 0755;
      foreach $flavour ( @static_flavours ) {
        my $content_type = (&$template($p,'content_type',$flavour));
        $content_type =~ s!\n.*!!s;
        my $fn = $p =~ m!^(.+)\.$file_extension$! ? $1 : "$p/index";
	param('-quiet') or print "$fn.$flavour\n";
	my $output_file = param('-no-output') ? "/dev/null" : "$static_dir/$fn.$flavour";
	my $fh_w = new FileHandle "> $output_file" or die "Couldn't open $output_file for writing: $!";  
	$output = '';
	print $fh_w 
            $indexes{$path} == 1
	      ? &generate('static', $p, '', $flavour, $content_type)
	      : &generate('static', '', $p, $flavour, $content_type);
	$fh_w->close;
	foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('reset') and $plugin->reset() }
      }
    }
  }
}

# Dynamic
else {
  my $content_type = (&$template($path_info,'content_type',$flavour));
  $content_type =~ s!\n.*!!s;

  $header = {-type=>$content_type, -charset => "UTF-8"};

  my $date = "$path_info_yr/$path_info_mo_num/$path_info_da";
  $date = "" if $date eq "//";
  print generate('dynamic', $path_info, $date, $flavour, $content_type);
}

# Plugins: End
foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('end') and $entries = $plugin->end() }

BEGIN {
  open F, ">", "/tmp/blosxom-generate.$<";
#  print F "$$: ", scalar(localtime()), "\n";
}

# Generate 
sub generate {
  my($static_or_dynamic, $currentdir, $date, $flavour, $content_type) = @_;
  print F "Starting generate: ($currentdir,$date) $flavour $content_type\n";
  my ($single_title, $single_metadata);
  my $datepath = $date;
  my %f = %files;

  # Plugins: Skip
  # Allow plugins to decide if we can cut short story generation
  my $skip; foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('skip') and defined($tmp = $plugin->skip()) and $skip = $tmp and last; }
  
  # Define default interpolation subroutine
  $interpolate = 
    sub {
      package blosxom;
      my $template = shift;
      $template =~ 
        s/(\$\w+(?:::)?\w*)/"defined $1 ? $1 : ''"/gee;
      return $template;
    };  

  my $ne;
  foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('num_entries') and defined($ne = $plugin->num_entries($currentdir, $date, $flavour)) and last; }
  $ne = $num_entries unless defined $ne;

  unless (defined($skip) and $skip) {

    # Plugins: Interpolate
    # Allow for the first encountered plugin::interpolate subroutine to 
    # override the default built-in interpolate subroutine
    my $tmp; foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('interpolate') and defined($tmp = $plugin->interpolate()) and $interpolate = $tmp and last; }
        
    # Acquire Stories
    my $curdate = '';
    my @stories;

    if ( $currentdir =~ /(.*?)([^\/]+)\.(.+)$/ and $2 ne 'index' ) {
      $currentdir = "$1$2.$file_extension";
      $files{"$datadir/$1$2.$file_extension"} and %f = ( "$datadir/$1$2.$file_extension" => $files{"$datadir/$1$2.$file_extension"} );
    } 
    else { 
      $currentdir =~ s!/index\..+$!!;
    }

    # Define a default sort subroutine
    my $sort = sub {
      my($files_ref) = @_;
      return sort { $files_ref->{$b} <=> $files_ref->{$a} } keys %$files_ref;
    };
  
    # Plugins: Sort
    # Allow for the first encountered plugin::sort subroutine to override the
    # default built-in sort subroutine
    my $tmp; foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('sort') and defined($tmp = $plugin->sort()) and $sort = $tmp and last; }
  
    foreach my $path_file ( &$sort(\%f, \%others) ) {
      last if $ne <= 0 && $date !~ /\d/;
      use vars qw/ $path $fn /;
      ($path,$fn) = $path_file =~ m!^$datadir/(?:(.*)/)?(.*)\.$file_extension!;
  
      # Only stories in the right hierarchy
      $DB::single=1 if $currentdir =~ /geo-trivia/;
      $path =~ /^$currentdir/ or $path_file eq "$datadir/$currentdir" or next;
      # print F "  generating from $path_file\n";
  
      # Prepend a slash for use in templates only if a path exists
      $path &&= "/$path";

      # Date fiddling for by-{year,month,day} archive views
      use vars qw/ $dw $mo $mo_num $da $ti $yr $hr $min $hr12 $ampm /;
      ($dw,$mo,$mo_num,$da,$ti,$yr) = nice_date($files{"$path_file"});
      ($hr,$min) = split /:/, $ti;
      ($hr12, $ampm) = $hr >= 12 ? ($hr - 12,'pm') : ($hr, 'am'); 
      $hr12 =~ s/^0//; $hr12 == 0 and $hr12 = 12;
  
      # Only stories from the right date
      my($path_info_yr,$path_info_mo_num, $path_info_da) = split /\//, $date;
      next if $path_info_yr && $yr != $path_info_yr; last if $path_info_yr && $yr < $path_info_yr; 
      next if $path_info_mo_num && $mo ne $num2month[$path_info_mo_num];
      next if $path_info_da && $da != $path_info_da; last if $path_info_da && $da < $path_info_da; 
  
      # Date 
      my $date = (&$template($path,'date',$flavour));
      
      # Plugins: Date
      foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('date') and $entries = $plugin->date($currentdir, \$date, $files{$path_file}, $dw,$mo,$mo_num,$da,$ti,$yr) }
  
      $date = &$interpolate($date);

      use vars qw/ $title $body $raw /;
      if (-f "$path_file" && $fh->open("< $path_file")) {
        chomp($title = <$fh>);
        chomp($body = join '', <$fh>);
        $fh->close;
        $raw = "$title\n$body";
      }
      my $story = (&$template($path,'story',$flavour));
  
      # Plugins: Story
      my $suppress;
      print F "    Calling story plugins\n";
      foreach my $plugin ( @plugins ) { 
	  if ($plugins{$plugin} > 0 and $plugin->can('story')) {
	      my $complete_path = "$datadir$path/$fn.$file_extension";
	      my %args = (
		  category   => $path, # directory of this story
		  filename   => $fn,   # filename of story, without suffix
		  storyref   => \$story,
		  titleref   => \$title,
		  bodyref    => \$body,

		  # If generating a section index, catpath
		  # names the section; if a date index, datepath
		  # is the date part. For the main page, neither.
		  catpath    => $currentdir,
		  datepath   => $datepath,

		  metadata   => $blosxom::metadata_hash{"$path/$fn"},
		  complete_path => $complete_path,
		  published_time => $files{$complete_path},
		  suppress => \$suppress,
		  );
	      $entries = $plugin->story(\%args);
#	      $entries = $plugin->story($path, $fn, \$story, \$title, \$body, $currentdir, $datepath, $blosxom::metadata_hash{"$path/$fn"})
	  }
      }
      print F "    Finished calling story plugins\n";

      # If an archive page has only one article, it is stored in
      # $single_title, which is later inserted into $page_title, which
      # appears in the <title> element.  Otherwise $single_title is
      # false. 20120826 mjd@plover.com
      $single_title = defined($single_title) ? "" : $title;
      # Similarly $single_meta contains the single article's metadata
      $single_metadata = defined($single_metadata) ? "" : $blosxom::metadata_hash{"$path/$fn"};
      print F "single_metadata is now $single_metadata ($path/$fn)\n";

      if ($content_type =~ m{\Wxml$}) {
        # Escape <, >, and &, and to produce valid RSS
        my %escape = ('<'=>'&lt;', '>'=>'&gt;', '&'=>'&amp;', '"'=>'&quot;');  
        my $escape_re  = join '|' => keys %escape;
        $title =~ s/($escape_re)/$escape{$1}/g;
        $body =~ s/($escape_re)/$escape{$1}/g;
      }
  
      my $st_date_header = "";
      if ($suppress) {
          print F "    Suppressed!\n";
      } else {
	  $curdate ne $date and $curdate = $date and $st_date_header = $date;
	  push @stories, $st_date_header .  &$interpolate($story);
      }
    
      $fh->close;
  
      $ne--;
    }
  
    # Head
    if ($single_title) {
        $page_title = "$blog_title : $single_title";
    } else {
        my $continuation_title = "";
        if ($currentdir) {
            if ($currentdir =~ /\.blog$/) { $continuation_title = ": untitled article '$currentdir'" }
            else { $continuation_title = ": category '$currentdir'" }
        } elsif ($date) {
            my $da = $date;
            $da =~ s{/+$}{};
            $continuation_title = ": $da archive";
        }
        $page_title = "$blog_title$continuation_title";
    }

    my $head = (&$template($currentdir,'head',$flavour));
  
    # Plugins: Head
    my $extra = { datepath => $datepath, dirfile => $currentdir,
		  single => $single_metadata, };
    print F "    Calling head plugins; single_metadata now $single_metadata\n";
    foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('head') and $entries = $plugin->head($currentdir, \$head, $extra) }
    $head = &$interpolate($head);
  
    $output .= $head;

    # Insert stories
    $output .= join "", @stories;

    # Foot
    my $foot = (&$template($currentdir,'foot',$flavour));
  
    # Plugins: Foot
    foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('foot') and $entries = $plugin->foot($currentdir, \$foot, $datepath) }
  
    $foot = &$interpolate($foot);
    $output .= $foot;

    # Plugins: Last
    foreach my $plugin ( @plugins ) { $plugins{$plugin} > 0 and $plugin->can('last') and $entries = $plugin->last() }

  } # End skip

  # Finally, add the header, if any and running dynamically
  $static_or_dynamic eq 'dynamic' and $header and $output = header($header) . $output;
  
  $output;
}


sub nice_date {
  my($unixtime) = @_;
  
  my $c_time = ctime($unixtime);
  my($dw,$mo,$da,$ti,$yr) = ( $c_time =~ /(\w{3}) +(\w{3}) +(\d{1,2}) +(\d{2}:\d{2}):\d{2} +(\d{4})$/ );
  $da = sprintf("%02d", $da);
  my $mo_num = $month2num{$mo};
  
  return ($dw,$mo,$mo_num,$da,$ti,$yr);
}


package varwatch;

sub TIESCALAR {
  my ($package, $fh) = @_;
  my $store = "";
  bless { store => \$store, fh => $fh } ;
}

sub FETCH {
  my $self = shift;
  ${$self->{store}};
}

sub STORE {
  my ($self, $val) = @_;
  my $old = $ {$self->{store}};
  my $olen = length($old);
  my ($act, $what) = ("set to", $val);
  if (substr($val, 0, $olen) eq $old) {
    ($act, $what) = ("appended", substr($val, $olen));
  }
  $what =~ tr/\n/ /;
  $what =~ s/\s+$//;
  my $fh = $self->{fh};
  print $fh "var $act '$what'\n";
  print $fh "  $_\n" for st();
  print $fh "\n";
  ${$self->{store}} = $val;
}

sub st {
  my @stack;
  my $spack = __PACKAGE__;
  my $N = 0;
  while (my @c = caller($N)) {
    my ($cpack, $file, $line, $sub) = @c;
    next if $sub =~ /^\Q$spack\E::/;
    push @stack, "$sub ($file:$line)";
  } continue { $N++ }
  @stack;
}

package warnstdout;

BEGIN { open DIAGNOSIS, ">", "/tmp/warnstdout";
        my $ofh = select DIAGNOSIS;
        $| = 1;
        select $ofh;
      }


sub rig_fh {
  my ($handle) = shift;
  my $mode = shift || "<";
  open my($fake_handle), "$mode&=", $handle or die $!;
  tie *$handle, __PACKAGE__, $fake_handle;
}

sub TIEHANDLE {
  my ($package, $truehandle) = @_;
  bless $truehandle => $package;
}

sub PRINT {
  my $true_handle = shift;
  print $true_handle @_;
  my $str = join("", @_);
#  $str = substr($str, 0, 78);
#  $str =~ tr/\n/ /;
  print DIAGNOSIS "$str:\n";
  print DIAGNOSIS "  $_\n" for st();
  print DIAGNOSIS "\n";
}

