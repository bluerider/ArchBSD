#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use File::Basename;
use File::Copy "cp";
use File::Temp qw/tempdir/;
use Cwd;

use Getopt::Std;
$Getopt::Std::STANDARD_HELP_VERSION = 1;

my $progname = basename($0);
my $pwd = getcwd;

sub HELPMESSAGE {
	print <<EOF
This tool should be executed in a standard repostiroy path
it will scan the current directory to figure out the
CARCH and repository name, and will search for the main
repositories in ../../../<repo>/os/<CARCH>/
EOF
;
	print "usage: $progname [options]\n";
	print "options:\n";
	print <<EOF
  -d    dry run, do not commit any files
EOF
;
}

our ($opt_d);
getopts('d');


if (not ($pwd =~ m@/(?<from_repo>\w+)/os/(?<carch>x86_64|i686)$@)) {
	print("Failed to figure out the repository name and architecture\n");
	print("from the current path: " . $pwd);
	exit(1);
}

my $repo  = $+{from_repo};
my $carch = $+{carch};
my $db    = "${repo}.db";
#my $workdir = tempdir(CLEANUP => 1);

sub add_pkg($$) {
	my ($name, $array) = @_;

	if ($name =~ m@^(?<name>.*?)-(?<ver>\d.*)$@) {
		my @arr = ($+{name}, $+{ver});
		push @$array, \@arr;
	}
}

sub read_db($) {
	my ($db) = @_;
	my @pkgarray;
	open(my $p, '-|', 'tar', '-tf', $db) or die "failed to read database for package list";
	while (<$p>) {
		next unless m@/$@;
		s@/$@@;
		add_pkg($_, \@pkgarray);
	}
	close($p);
	return \@pkgarray;
}

sub load_repos() {
	my %repos;

	for my $r (qw/core extra community/) {
		my $fromdb = "../../../$r/os/$carch/${r}.db.tar.gz";
		#my $targdb = "$workdir/${r}.db.tar.gz";
		#unless (cp($fromdb, $targdb)) {
  	  	#  print "${r}.db.tar.gz not found in ../../../$r/os/$carch/\n";
  	  	#  next;
		#}
		next unless -e $fromdb;

		my $targpkgs = read_db $fromdb;
		next if 0 == scalar(@$targpkgs);
		$repos{$r} = $targpkgs;
	}

	return %repos;
}


printf("Committing from $repo ($carch)\n");

my $new_packages = read_db $db;

if (scalar(@$new_packages) == 0) {
	print("No packages in $db\n");
	exit(0);
}

my %repos = load_repos;

sub set_repo_for($) {
	my ($pkg) = @_;
	my $found = undef;
	keys %repos;
	OUTER:
	while ( my ($repo, $pkgs) = each %repos ) {
		for my $pkgref (@$pkgs) {
			if (@{$pkg}[0] eq @{$pkgref}[0]) {
				if (defined($found)) {
					print("WARNING: @{$pkg}[0] exists in multiple repositories!\n");
					$found = undef;
					last OUTER;
				}
				$found = $repo;
			}
		}
	}

	if (defined($found)) {
		push @$pkg, $found;
	}

	if (scalar(@$pkg) == 2) {
		#print("Don't know which repository contains @{$pkg}[0]\n");
		my $answer;
		print("Choose repository for @{$pkg}[0]: ");
		$| = 1;
		QUESTION:
		while (defined($answer = <>)) {
			chomp($answer);
			keys %repos;
			while ( my ($repo, $pkgs) = each %repos ) {
				if ($answer eq $repo) {
					push @$pkg, $repo;
					last QUESTION;
				}
			}
			print("Repository '$answer' has not been found previously!\n");
			print("Choose repository for @{$pkg}[0]: ");
		}
		if (scalar(@$pkg) == 2) {
			exit(0);
		}
	}
}

my $err = 0;
for my $pkg (@$new_packages) {
	set_repo_for($pkg);
	my ($name, $ver, $target) = @$pkg;
	my $tar = "$name-$ver-$carch.pkg.tar.xz";
	my $sig = "$tar.sig";
    # check for a signature file:
    if (not -e $tar) {
		$tar = "$name-$ver-any.pkg.tar.xz";
		$sig = "$tar.sig";
	}
    if (not -e $tar) {
    	print("Package archive missing for $name-$ver\n");
    	$err = 1;
    }
    if (not -e $sig) {
    	print("Signature missing for $name-$ver\n");
    	$err = 1;
    }
    push @$pkg, ($tar, $sig);
}

exit(1) if $err;

# First copy all the files
my %tarlist;
for my $pkg (@$new_packages) {
	my ($name, $ver, $target, $tar, $sig) = @$pkg;
	my $dest = "../../../$target/os/$carch";
	if (!$opt_d) {
		print ("copying: $tar -> $dest/$tar\n");
		cp $tar, "$dest/$tar" or die "Copying $tar to destination failed: $!";
		print ("copying: $sig -> $dest/$sig\n");
		cp $sig, "$dest/$sig" or die "Copying $sig to destination failed: $!";
	} else {
		print ("NOT copying: $tar -> $dest/$tar\n");
		print ("NOT copying: $sig -> $dest/$sig\n");
	}
	if (exists($tarlist{$target})) {
		push @{$tarlist{$target}}, $tar;
	} else {
		$tarlist{$target} = [$tar];
	}
}

# Then repo-add them in bulks
while (my ($repo, $files) = each %tarlist) {
	chdir ("../../../$repo/os/$carch") or die "failed to change directory to ../../../$repo/os/$carch/";
	if (!$opt_d) {
		print("Committing to $repo: ", join(", ", @$files), "\n");
		if (system("repo-add", "$repo.db.tar.gz", @$files) != 0) {
			print("Failed to commit packages to $repo");
		}
	} else {
		print("NOT committing to $repo: ", join(", ", @$files), "\n");
	}
	chdir $pwd;
}

# Remove old files
for my $pkg (@$new_packages) {
	my ($name, $ver, $target) = @$pkg;
	my $tar = "$name-$ver-$carch.pkg.tar.xz";
	my $sig = "$tar.sig";
	my $dest = "../../../$target/os/$carch";
	chdir $dest;
	my @files = <${name}-[0-9]*.pkg.tar.xz>;
	for my $old (@files) {
		next if $old eq $tar;
		if (!$opt_d) {
			print("Deleting old files: $old $old.sig\n");
			unlink($old);
			unlink("${old}.sig");
		} else {
			print("NOT deleting old files: $old $old.sig\n");
		}
	}
	chdir $pwd;
}
