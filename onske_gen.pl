#!/usr/bin/perl
use strict;
use warnings;
use Template;
use DateTime;
use Data::Dumper;

use vars qw/@argv/;

my ($file, $template, $year) = @ARGV;

unless ($file) {
	$year = DateTime->now->year;
	$file = $year . '.txt';
}

die ("Please provide file") unless ($file && -r $file);

unless ($template) {
	$template = 'tt.htm.txt';
}

die ("Please provide template: $template") unless(-r $template);

if (!$year && $file =~ /(20\d{2})/) {
	$year = $1;
}

die ("Please provide year") unless($year);

open(FILE, $file) or die ($!);

my %categories = ();
my @wishes = ();
my $last_category;

while (<FILE>) {
	chomp;
	next if (/^\s*$/ || /^\*/);

	unless (/^\s/) {
		push_to_category($last_category, @wishes) if ($last_category);
		@wishes = ();
		$last_category = $_;
		next;
	}

	s/^\s+//g;
#	s!\s*//.*!!g;
	s!(http(s)?://[\w_/\.-]+)!<a href="$1">$1</a>!g;

	#[% x FILTER html %]

	push @wishes, $_;
}
push_to_category($last_category, @wishes);

close (FILE);

sub push_to_category {
	my $name = shift;
	return unless(@_);
	$categories{$name} = [sort {lc $a cmp lc $b} @_];
}

my $t = Template->new({
	INTERPOLATE  => 1,
#    DEBUG        => 'all',
});

my @categories = map {[$_, $categories{$_} ]} sort {lc $a cmp lc $b} keys %categories;


$t->process(
	$template,
	{
		year => $year,
#		data => \%categories,
		data => \@categories,
	}
) || die $t->error(), "\n";

