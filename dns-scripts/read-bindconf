#!/usr/bin/perl

# Copyright (c) 2015
# Olaf Schreck <chakl@syscall.de>, syscall IT GmbH

# Read BIND9 zone config data and zonefiles and write them to STDOUT as an 
# XML data structure conforming to the zones node in data-samples/data.xml
#
# initial version, zonefiles are not parsed yet


use strict;
use warnings;

use Data::Dumper;
use XML::Simple;

my $VERSION = '0.1';

my $ZONES = { 'zones' => [] };

my $zones_in = "data-samples/zones-samplefile";
my $zonefile_dir = "data-samples/master";

my $rawzones;
open(ZF, $zones_in) or die "failed to open zones file: $!";
while (<ZF>) {
    next if /^\s*\/\//;
    next if /^\s*\#/;
    next if /^\s*$/;
    $rawzones .= $_;    
#    print;
}
close ZF;

#print $rawzones;
#exit;

my ($thiszone, $thisconf);
foreach my $zs (split /zone/i, $rawzones) {
    $thiszone = $thisconf = '';
#    print "##$zs##\n";
    if ($zs) {
#	print "zone $zs\n";
	$zs =~ s/\n/ /g;
	$zs =~ /\s*\"(.*?)\"\s+\{\s*(.*)\s*\}\s*;\s*/s;
	$thiszone = $1;
	$thisconf = $2;
#	print "thiszone $thiszone thisconf $thisconf\n";
	push(@{$ZONES->{zone}}, parse_zoneconf($thiszone, $thisconf));
    }
}
#print Dumper($ZONES);
#exit;

print XMLout($ZONES, KeepRoot => 1, KeyAttr => ['name' => 'zone'], 
	     RootName => 'zones', SuppressEmpty => undef);


sub parse_zoneconf {
    my ($zone, $conf) = @_;
    my $out = { origin => $zone, masters => undef, zonedata => undef};

    # set zonetype attribute - might go away
    if ($zone =~ /in-addr.arpa$/) {
	$out->{zonetype} = 'reverse';
    } else {
	$out->{zonetype} = 'forward';
    }

    # fill masters node
    my ($rawmasters, @masters);
    while ($conf) {
	if ($conf =~ /type\s+(\w+)\s*;/si) {
	    $out->{type} = $1;
	    $conf =~ s/type\s+(.*?)\s*;//;
	} elsif ($conf =~ /file\s+"(.*?)"\s*;/si) {
	    $out->{file} = $1;
	    $conf =~ s/file\s+"(.*?)"\s*;//;
	} elsif ($conf =~ /masters\s+\{\s*(.*?)\s*\}\s*;/si) {
	    $rawmasters = $1;
	    @masters = split(/\s*;\s*/, $rawmasters);
	    $out->{masters}->{master} = \@masters;
	    $conf =~ s/masters\s+\{\s*(.*?)\s*\}\s*;//si;
	} elsif ($conf =~ /notify\s+(\w+)\s*;/si) {
	    $out->{notify} = $1;
	    $conf =~ s/notify\s+(.*?)\s*;//;

	} elsif ($conf =~ /^\s*$/s) {
	    $conf = '';
	} else {
	    print $conf;
	}
    }
    $out;
}

#print Dumper($ZONES);
