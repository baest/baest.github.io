#!/usr/bin/env perl
use 5.020;
use warnings;
#use Template;
use utf8;
use Mojo::Template;
use DateTime;
use Data::Dumper;
#use WWW::Shorten::Googl;
use WWW::Shorten::TinyURL;
#use WWW::Shorten::Bitly;
use JSON::MaybeXS;
use File::Slurp::Tiny qw/read_file write_file read_lines/;
use LWP::UserAgent;

#https://www.engadget.com/2018/03/30/google-shutting-down-goo-gl-url-shortening-service/
#https://metacpan.org/pod/WWW::Shorten::Bitly
#bitly access token: 92aaefbca552ec8bce0899b8a1f241f4af399389

my $ua = LWP::UserAgent->new;
$ua->max_redirect(0);
my $json = JSON::MaybeXS->new(canonical => 1);

#$ENV{GOOGLE_API_KEY} = 'AIzaSyBjjUbAIwmM7bt-3v1QdOC4XcZxk5zlK3Y';

my ($file, $template, $year) = @ARGV;
my $name;
my %url_map;
my %categories = ();

my $url_file = 'urls.txt';
if (-f $url_file) {
	my $file = read_file($url_file);
	%url_map = %{$json->decode($file)};
}

unless ($file) {
	$year = DateTime->now->year;
	$file = $year . '.txt';
}

#die ("Please provide file") unless ($file && -r $file);

unless ($template) {
	$template = 'tt.htm.txt';
}

die ("Please provide template: $template") unless(-r $template);

if (!$year && $file =~ /(20\d{2})/) {
	$year = $1;
}

die ("Please provide year") unless($year);

for (qw/martin isabella gitte/) {
	my $input_file = "$_\_2018.txt";
	my $output_file = "gen/\u$_\_ønskeseddel.html";
	next unless -r $input_file;
	write_onske_file($input_file, $output_file);
}

write_file($url_file, $json->encode(\%url_map));

sub write_onske_file {
	my ($file, $output_file) = @_;
	%categories = ();

	my @lines = read_lines($file, chomp => 1);
	#open(FILE, $file) or die ($!);

	my @wishes = ();
	my $last_category;

	for (@lines) {
	#while (defined ($_ = <FILE>)) {
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
		s!(http(s)?://[\wæøåÆØÅ_/\.\#\?\!\=-]+)!get_link($1)!eg;

		push @wishes, $_;
	}

	#close (FILE);

	push_to_category($last_category, @wishes);

	my @categories = map {[$_, $categories{$_} ]} sort {lc $a cmp lc $b} keys %categories;

	my $output = Mojo::Template->new(vars => 1)->render_file($template, {
			year => $year,
			data => \@categories,
			name => $name,
	}) || die "$@\n";

	write_file($output_file, $output);
}

sub get_link {
	my ($url) = @_;
	if (exists $url_map{$url}) {
		$url = $url_map{$url};
	}
	elsif ($url !~ /tinyurl\.com/) {
		my $old_url = $url;
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
