#!/usr/bin/env perl
use strict;
use warnings;
use Template;
use DateTime;
use Data::Dumper;
use WWW::Shorten::Googl;
use JSON::MaybeXS;
use File::Slurp::Tiny qw/read_file write_file/;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->max_redirect(0);
my $json = JSON::MaybeXS->new(canonical => 1);

$ENV{GOOGLE_API_KEY} = 'AIzaSyBjjUbAIwmM7bt-3v1QdOC4XcZxk5zlK3Y';

my ($file, $template, $year) = @ARGV;
my $name;
my %url_map;

my $url_file = 'urls.txt';
if (-f $url_file) {
	my $file = read_file($url_file);
	%url_map = %{$json->decode($file)};
}

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
	if (/^\*\s*name:\s+(\w+)/) {
		$name = $1;
	}
	next if (/^\s*$/ || /^\*/);

	unless (/^\s/) {
		push_to_category($last_category, @wishes) if ($last_category);
		@wishes = ();
		$last_category = $_;
		next;
	}

	s/^\s+//g;
#	s!\s*//.*!!g;
	s!(http(s)?://[\wæøåÆØÅ_/\.\#\?\!-]+)!get_link($1)!eg;

	#[% x FILTER html %]

	push @wishes, $_;
}
push_to_category($last_category, @wishes);

write_file($url_file, $json->encode(\%url_map));

close (FILE);

sub get_link {
	my ($url) = @_;
	if (exists $url_map{$url}) {
		$url = $url_map{$url};
	}
	elsif ($url !~ /goo\.gl/) {
		my $old_url = $url;
		warn $url;
		$url = makeashorterlink($url);
		$url_map{$old_url} = $url;
	}
	else {
		my $response = $ua->get($url);
		warn $url, ' -> ', $response->header('location'), "\n";
	}
	return qq!<a href="$url">$url</a>!;
}

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
		name => $name,
	}
) || die $t->error(), "\n";

