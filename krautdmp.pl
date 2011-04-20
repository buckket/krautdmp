#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;

use threads;
use threads::shared;

use constant THREADS => 6;
use constant VERBOSE => 1;

# krautdmp.pl
# by MrLoom
# 03/27/2011


my ($board, $threadid) = @{&parseInput(@ARGV)};
my $threadurl = "http://krautchan.net/${board}/thread-${threadid}.html";
my $dir = "${board}-${threadid}/";

my @queue :shared;

my $ua = LWP::UserAgent->new;
&beVerbose("[+] Getting page...\n");
my $response = $ua->get($threadurl);
if ($response->code == 200) {
	if(! -d $dir) {
		&beVerbose("[+] Creating folder...\n");
		mkdir $dir;     
		mkdir "${dir}files";
		mkdir "${dir}thumbnails";

		&pushQueue(["http://krautchan.net/css/style.css", "${dir}style.css"]);
		&pushQueue(["http://krautchan.net/banners/banner-dott.gif", "${dir}banner.gif"]);
	}
	
	my $content = $response->decoded_content;
	
	&beVerbose("[+] Adding thumbnails to queue...\n");
	while ($content =~ m/<img.*src=\/thumbnails\/(\d*\.\w*)/g) {
		if(! -e "$dir/thumbnails/$1") {
			&pushQueue(["http://krautchan.net/thumbnails/$1", "${dir}thumbnails/$1"]);
		}
	}
	
	&beVerbose("[+] Adding images to queue...\n");
	while ($content =~ m/<a href="\/files\/(\d*\..*)" target="_blank">/g) {
		if(! -e "$dir/files/$1") {
			&pushQueue(["http://krautchan.net/files/$1", "${dir}files/$1"]);
		}
	}
	
	#FILTER, FILTER TILL WE DIE!!
	&beVerbose("[+] Applying filter...\n");
	while ($content =~ s/<script[^>]*>.*?<\/script>//igs) {}
	while ($content =~ s/<form action="\/post".*\n<\/form>//s) {}
	while ($content =~ s/<h2>.*<\/h2>//) {}
	while ($content =~ s/<h1>(.*)<\/h1>\s*<hr>/<h1>$1<\/h1>\n/s) {}
	while ($content =~ s/<div style="float: left">.*]\s*<\/div>//s) {}
	while ($content =~ s/<img src="\/images\/button-paint\.gif" border="0" width="15" height="15">//) {}
	while ($content =~ s/src="\/images\/balls\/.*\.png"//) {}
	while ($content =~ s/src="\/images\/button-.*\.gif"//) {} 
	while ($content =~ s/\/css\/style\.css/style\.css/) {}
	while ($content =~ s/\/thumbnails\//thumbnails\//) {}
	while ($content =~ s/\/files\//files\//) {}
	while ($content =~ s/\/download\/(\d*\..*)\/.*"/files\/$1"/) {}
	while ($content =~ s/<img src="\/banner\/.*"/<img src="banner\.gif"/) {}
	
	&beVerbose("[+] Writting index...\n");
	open INDEX, "+>", "${dir}index.html";
	binmode INDEX, ":utf8";
	print INDEX $content;
	close INDEX;
	
	&beVerbose("[+] ". scalar @queue . " files to get...\n");
	&beVerbose("[+] Spawning ".THREADS." threads... \n");
	for(my $i = 0; $i < THREADS; $i++) {
		threads->create(\&threadWork);
	}
	while(threads->list()) {
		foreach my $thr (threads->list()) {
			$thr->join();
		}
	}
}
else { &throwError('invalid result')}


sub pushQueue {
	my $work = pop @_;
	my @array :shared;
	push @array, ${$work}[0];
	push @array, ${$work}[1];
	push @queue, \@array;
}

sub threadWork {
	my $work = pop @queue;
	if(defined($work)) {
		my $ua = LWP::UserAgent->new;
		$ua->get(${$work}[0], ":content_file" => ${$work}[1],);
	}
	if(scalar @queue > 0) {
		threads->create(\&threadWork);
	}
}

sub throwError {
	my $error = pop @_;
	die("[-] $error\n");
}

sub beVerbose {
	my $verbose = pop @_;
	if(VERBOSE) { print("$verbose") }
}

sub parseInput {
	my $ARGV = pop @_;
	if(defined($ARGV)) {
		if($ARGV =~ /http:\/\/krautchan\.net\/(.*)\/thread-(.*)\.html/g) {
			return [$1, $2];
		}
		elsif($ARGV =~ /http:\/\/krautchan\.net\/board\/(.*)\/thread\/(.*)/g) {
			return [$1, $2];
		}
		else { &throwError('Gibbe valid URL') }
	}
	else  {&throwError('Gibbe argument') }
}
