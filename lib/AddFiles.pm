#! /usr/bin/perl -w

# Usage:
#
#   use AddFiles;
#
#   exported functions:
#     AddFiles(dir, file_list, ext_dir, tag);

=head1 AddFiles

C<AddFiles.pm> is a perl module that can be used to extract files from
rpms. It exports the following symbols:

=over

=item *

C<AddFiles(dir, file_list, ext_dir, tag)>

=back

=head2 Usage

use AddFiles;

=head2 Description

=over

=item *

C<AddFiles(dir, file_list, ext_dir, tag)>

C<AddFiles> extracts the files in C<file_list> and puts them into C<dir>.
Files that are not to be taken from rpms are copied from C<ext_dir>.

The syntax of the file list is rather simple; please have a look at those
provided with this package to see how it works. A syntax description follows
later...

On any failure, C<exit( )> is called.


=back

=cut


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
require Exporter;
@ISA = qw ( Exporter );
@EXPORT = qw ( AddFiles );

use strict 'vars';
use integer;

use ReadConfig;

sub AddFiles
{
  local $_;
  my ($dir, $file_list, $ext_dir, $arch, $if_val, $tag);
  my ($rpms, $tdir, $p, $r, $d, $u, $g, $files);

  ($dir, $file_list, $ext_dir, $tag) = @_;

  if(!$AutoBuild) {
    $rpms = "$ConfigData{SuSE_base}/suse";
    die "$Script: where are the rpms?" unless $ConfigData{SuSE_base} && -d $rpms;
  }
  else {
    print STDERR "running in autobuild environment\n"
  }

  if(! -d $dir) {
    die "$Script: failed to create $dir ($!)" unless mkdir $dir, 0755;
  }

  $tdir = "${TmpBase}.dir";
  die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # now we really start...

  die "$Script: no such file list: $file_list" unless open F, $file_list;

  $arch = `uname -m`; chomp $arch;
  $arch = "ix86" if $arch =~ /^i\d86$/;
  $arch = "sparc" if $arch =~ /^sparc/;

  $tag = "" unless defined $tag;

  $if_val = 0;

  while(<F>) {
    chomp;
    next if /^(\s*|\s*#.*)$/;

#    printf ".<%x>%s\n", $if_val, $_;

    if(/^endif/) { $if_val >>= 1; next }

    if(/^else/) { $if_val ^= 1; next }

    if(/^ifarch\s+(\S+)/)  { $if_val <<= 1; $if_val |= 1 if $1 ne $arch; next }
    if(/^ifnarch\s+(\S+)/) { $if_val <<= 1; $if_val |= 1 if $1 eq $arch; next }
    if(/^ifdef\s+(\S+)/)   { $if_val <<= 1; $if_val |= 1 if $1 ne $tag;  next }
    if(/^ifndef\s+(\S+)/)  { $if_val <<= 1; $if_val |= 1 if $1 eq $tag;  next }

    next if $if_val;

    s/<kernel_ver>/$ConfigData{kernel_ver}/g;
    s/<kernel_rpm>/$ConfigData{kernel_rpm}/g;
    s/<kernel_img>/$ConfigData{kernel_img}/g;

#    printf "*<%x>%s\n", $if_val, $_;

    if(/^(\S+):\s*$/) {
      $p = $1;
      if($AutoBuild) {
        SUSystem "rm -rf $tdir" and
          die "$Script: failed to remove $tdir";
        die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;
#        SUSystem "sh -c 'cd / ; rpm -ql $p | tar -T - -cf - | tar -C $tdir -xpf -'" and
#          die "$Script: failed to extract $p";
        print STDERR "adding package $p...\n";
        SUSystem "sh -c 'cd $tdir ; rpm -ql $p | cpio --quiet -o 2>/dev/null | cpio --quiet -dim --no-absolute-filenames'" and
          die "$Script: failed to extract $r";
      }
      else {
        if($p =~ /^\//) {
          $r = $p;
          die "$Script: no such package: $r" unless -f $r;
        }
        else {
          $r = `echo -n $rpms/*/$p.rpm`;
          die "$Script: no such package: $p.rpm" if $r eq "$rpms/*/$p.rpm";
        }
        SUSystem "rm -rf $tdir" and
          die "$Script: failed to remove $tdir";
        die "$Script: failed to create $tdir ($!)" unless mkdir $tdir, 0777;
        SUSystem "sh -c 'cd $tdir ; rpm2cpio $r | cpio --quiet -dim --no-absolute-filenames'" and
          die "$Script: failed to extract $r";
      }
    }
    elsif(/^\s+(.*)$/) {
      $files = $1;
      $files =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c '( cd $tdir; tar -cf - $files ) | tar -C $dir -xpf -'" and
        die "$Script: failed to copy $files";
    }
    elsif(/^d\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; mkdir -p $d'" and
        die "$Script: failed to create $d";
    }
    elsif(/^t\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; touch $d'" and
        die "$Script: failed to touch $d";
    }
    elsif(/^r\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; rm -rf $d'" and
        die "$Script: failed to remove $d";
    }
    elsif(/^S\s+(.+)$/) {
      $d = $1; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; strip $d'" and
        die "$Script: failed to strip $d";
    }
    elsif(/^l\s+(\S+)\s+(\S+)$/) {
      SUSystem "ln $dir/$1 $dir/$2" and
        die "$Script: failed to link $1 to $2";
    }
    elsif(/^s\s+(\S+)\s+(\S+)$/) {
      SUSystem "ln -s $1 $dir/$2" and
        die "$Script: failed to symlink $1 to $2";
    }
    elsif(/^m\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -a $tdir/$1 $dir/$2" and
        die "$Script: failed to move $1 to $2";
    }
    elsif(/^a\s+(\S+)\s+(\S+)$/) {
      SUSystem "sh -c \"cp -a $tdir/$1 $dir/$2\"" and
        print STDERR "$Script: $1 not copied to $2 (ignored)\n";
    }
    elsif(/^x\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -dR $ext_dir/$1 $dir/$2" and
        die "$Script: failed to move $1 to $2";
    }
    elsif(/^X\s+(\S+)\s+(\S+)$/) {
      SUSystem "cp -fdR $1 $dir/$2 2>/dev/null" and
        print STDERR "$Script: $1 not copied to $2 (ignored)\n";
    }
    elsif(/^g\s+(\S+)\s+(\S+)$/) {
      SUSystem "sh -c 'gunzip -c $tdir/$1 >$dir/$2'" and
        die "$Script: could not uncompress $1 to $2";
    }
    elsif(/^c\s+(\d+)\s+(\S+)\s+(\S+)\s+(.+)$/) {
      $p = $1; $u = $2; $g = $3;
      $d = $4; $d =~ s.(^|\s)/.$1.g;
      SUSystem "sh -c 'cd $dir; chown $u.$g $d'" and
        die "$Script: failto to change owner of $d to $u.$g";
      SUSystem "sh -c 'cd $dir; chmod $p $d'" and
        die "$Script: failto to change perms of $d to $p";
    }
    elsif(/^b\s+(\d+)\s+(\d+)\s+(\S+)$/) {
      SUSystem "mknod $dir/$3 b $1 $2" and
        die "$Script: failto to make block dev $3 ($1, $2)";
    }
    elsif(/^c\s+(\d+)\s+(\d+)\s+(\S+)$/) {
      SUSystem "mknod $dir/$3 c $1 $2" and
        die "$Script: failto to make char dev $3 ($1, $2)";
    }
    else {
      die "$Script: unknown entry: \"$_\"\n";
    }

  }

  close F;

  SUSystem "rm -rf $tdir";

  return 1;
}

1;
