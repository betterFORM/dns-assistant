#!/usr/bin/perl

# Copyright (c) 2015
# Olaf Schreck <chakl@syscall.de>, syscall IT GmbH

# Read BIND9 zone config data and zonefiles and write them to STDOUT as an 
# XML data structure conforming to the "zones" node in data-samples/data.xml


use strict;
use warnings;

use Data::Dumper;
use Net::DNS::ZoneFile;
use XML::Simple;
use Syscall::Util::Log;

my $CONF = {
    debug  => 0,
    prefix => 'data-samples',
};

my $RUN = {
    myname      => 'read-bindconf',
    version     => '0.3',
    logfac      => 'daemon',
};

my $LOG = Syscall::Util::Log->new(Myname => $RUN->{myname}, 
				  SyslogFacility => $RUN->{logfac})
    or fatal(1, "failed to create logging handle");

my $ZONES = { 'zones' => [] };

my $zones_in = $CONF->{prefix} . '/zones-samplefile';

my $rawzones;
open(ZF, $zones_in) or fatal(1, "failed to open $zones_in: $!");
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

    # parse zone config, fill masters node
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

    # fill zonedata element from zonefile
    if ($out->{type} eq 'master') {
	$out->{zonedata} = parse_zonefile($zone, $out->{file});
    }

    $out;
}


sub parse_zonefile {
    my ($zone, $file) = @_;
    my $out = { rr => [] };
    my $zfname = $CONF->{prefix} . '/' . $file;
    # XXX check err, may croak
    my $zonefile = new Net::DNS::ZoneFile($zfname, $zone);

    $out->{ttl} = $zonefile->ttl if $zonefile->ttl;

    my ($rr, $rrref);
    my $id = 1;
    while ($rr = $zonefile->read) {
	if ($rr->type eq 'SOA') {
	    $out->{mname}   = $rr->mname;
	    $out->{rname}   = $rr->rname;
	    $out->{serial}  = $rr->serial;
	    $out->{refresh} = $rr->refresh;
	    $out->{retry}   = $rr->retry;
	    $out->{expire}  = $rr->expire;
	    $out->{minimum} = $rr->minimum;
	} else {
	    $rrref = { id => "id${id}", owner => $rr->owner, 
		       type => $rr->type, ttl => $rr->ttl };
	    if ($rr->type eq 'NS') {
		$rrref->{val} = $rr->nsdname;
	    } elsif ($rr->type eq 'MX') {
		$rrref->{val} = $rr->exchange;
		$rrref->{prio} = $rr->preference;
	    } elsif ($rr->type eq 'A') {
		$rrref->{val} = $rr->address;
	    } elsif ($rr->type eq 'AAAA') {
		$rrref->{val} = $rr->address_short;
	    } elsif ($rr->type eq 'SPF') {
		$rrref->{val} = $rr->spfdata;
	    } elsif ($rr->type eq 'TXT') {
		$rrref->{val} = $rr->txtdata;
	    } elsif ($rr->type eq 'SRV') {
		$rrref->{prio}   = $rr->priority;
		$rrref->{weight} = $rr->weight;
		$rrref->{port}   = $rr->port;
		$rrref->{val}    = $rr->target;
	    } elsif ($rr->type eq 'TLSA') {
		$rrref->{val}          = $rr->cert;
		$rrref->{usage}        = $rr->usage;
		$rrref->{selector}     = $rr->selector;
		$rrref->{matchingtype} = $rr->matchingtype;
	    } elsif ($rr->type eq 'PTR') {
		$rrref->{val} = $rr->ptrdname;
	    } else {
		$LOG->warn("unrecognized RR type: ", $rr->type);
	    }
	    
	    push(@{$out->{rr}}, $rrref);
	    $id++;
	}
    }

    $out;
}


sub fatal {
    my ($code, $msg) = @_;
    print STDERR "fatal: $msg\n";
    $LOG->err("fatal: $msg");
    exit($code);
}

