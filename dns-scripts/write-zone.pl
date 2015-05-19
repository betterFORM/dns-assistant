#!/usr/bin/perl

# Copyright (c) 2015
# Olaf Schreck <chakl@syscall.de>, syscall IT GmbH

# Expect an XML fragment that represents a DNS zone on STDIN, and create 
# BIND9 config fragment and zonefile from this data.
#
# See data-samples/zonedata-sample*.xml for sample XML data.
#
# initial version


use strict;
use warnings;

use Data::Dumper;
use Net::DNS::RR;
use XML::Simple;

my $VERSION = '0.1';

# directory prefix for created files
my $PREFIX = 'stage';

# order of record types for nice formatting
my @TYPEORDER = qw( NS MX A AAAA SPF TXT SRV CNAME PTR );

# parse XML from STDIN
# exits 255 and with err msg on parse errors, need to catch that correctly
my $ref = XMLin('-', KeyAttr => {'rr' => 'id'});
#print Dumper($ref);

my $outconf = $ref->{origin} . '.conf';
my $outfile = $ref->{file};

create_conf();
create_zonefile() if $ref->{type} eq 'master';

# create BIND9 config fragment for the zone
sub create_conf {
    open(CF, ">$PREFIX/$outconf") or die "open conf $outconf: $!";
    print CF "zone \"", $ref->{origin}, "\" {\n";
    if ($ref->{type} eq 'master') {
	print CF "    type master;\n    file \"", $outfile, "\";\n";
    }
    if ($ref->{type} eq 'slave') {
	print CF "    type slave;\n    masters { ";
	foreach (values %{$ref->{masters}}) {
	    print CF $_, "; ";
	}
	print CF "};\n";
	if ($ref->{file}) {
	    print CF "    file \"", $outfile, "\";\n";
	}
    }
    print CF "};\n";
    close CF;
}


# create BIND9 zone file for the zone
sub create_zonefile {
    my $soa = new Net::DNS::RR(
	name    => $ref->{origin},
	ttl     => $ref->{zonedata}->{ttl},
	type    => 'SOA',
	mname   => $ref->{zonedata}->{mname},
	rname   => $ref->{zonedata}->{rname},
	serial  => $ref->{zonedata}->{serial},
	refresh => $ref->{zonedata}->{refresh},
	retry   => $ref->{zonedata}->{retry},
	expire  => $ref->{zonedata}->{expire},
	minimum => $ref->{zonedata}->{minimum},
	);

    my $rrhref = $ref->{zonedata}->{rr};
    my $sorthref = { '_origin' => {} };

    # fill $sorthref (defines order in which records are written out)
    my ($rtype, $owner);
    foreach my $r (keys %$rrhref) {
	$rtype = $rrhref->{$r}->{type};
	$owner = $rrhref->{$r}->{owner};
	if ($owner eq '@' or $owner eq $ref->{origin}) {
	    push(@{$sorthref->{_origin}->{$rtype}}, $r);
	} else {
	    push(@{$sorthref->{$owner}->{$rtype}}, $r);
	}
    }
#    print Dumper($sorthref);

    # write zonefile
    open(OUT, ">$PREFIX/$outfile") or die "open outfile $outfile: $!";
    printf(OUT "\$TTL %d\n\$ORIGIN %s.\n", 
	   $ref->{zonedata}->{ttl}, $ref->{origin});
    print OUT $soa->string, "\n";

    foreach my $o ('_origin', sort grep !/^_/, keys %$sorthref) {
	foreach my $t (@TYPEORDER) {
	    if (exists $sorthref->{$o}->{$t}) {
		foreach my $id (@{$sorthref->{$o}->{$t}}) {
		    print OUT pprint_rr($rrhref->{$id}), "\n";
#		    print Dumper($rrhref->{$id});
		}
	    }
	}
	$o =~ /^_/ && print OUT "\n";
    }
    close OUT;
}


# return zone file formatted strings for resource record
sub pprint_rr {
    my $data = shift;
    my $type = $data->{type};
    my $name = $data->{owner};
    unless ($name eq $ref->{origin} or $name =~ /\.$/) {
	$name .= '.' . $ref->{origin};
    }
    my $ttl = $data->{ttl} ? $data->{ttl} : $ref->{zonedata}->{ttl};
    my $rr = new Net::DNS::RR(
	name    => $name,
	ttl     => $ttl,
	type    => $type,
	);
    my $out;
    if ($type eq 'A' or $type eq 'AAAA') {
	$rr->address($data->{val});
	$out = $rr->string;
    } elsif ($type eq 'NS') {
	$rr->nsdname($data->{val});
	$out = $rr->string;
    } elsif ($type eq 'MX') {
	$rr->exchange($data->{val});
	$rr->preference($data->{prio});
	$out = $rr->string;
    } elsif ($type eq 'CNAME') {
	$rr->cname($data->{val});
	$out = $rr->string;
    } elsif ($type eq 'TXT') {
	$rr->txtdata($data->{val});
	$out = $rr->string;
    } elsif ($type eq 'SPF') {
	$rr->spfdata($data->{val});
	$out = $rr->string;
    } elsif ($type eq 'PTR') {
	$rr->ptrdname($data->{val});
	$out = $rr->string;
    }
    $out;
}

