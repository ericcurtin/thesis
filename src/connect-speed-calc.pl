#!/usr/bin/perl

use strict;
use warnings;

my $time_namelookup    = 0;
my $time_connect       = 0;
my $time_appconnect    = 0;
my $time_pretransfer   = 0;
my $time_redirect      = 0;
my $time_starttransfer = 0;
my $time_total         = 0;
my %http_codes;
my $total_lines = 0;

my $file = $ARGV[0];
open( my $fh, '<', $file ) or die "Can't read file '$file' [$!]\n";
while ( my $line = <$fh> ) {
    my @fields = split( /,/, $line );
    $time_namelookup    += $fields[0];
    $time_connect       += $fields[1];
    $time_appconnect    += $fields[2];
    $time_pretransfer   += $fields[3];
    $time_redirect      += $fields[4];
    $time_starttransfer += $fields[5];
    $time_total         += $fields[6];

    chomp( $fields[7] );
    if ( $http_codes{ $fields[7] } ) {
        ++$http_codes{ $fields[7] };
    }
    else {
        $http_codes{ $fields[7] } = 1;
    }

    ++$total_lines;
}

my $avg_namelookup    = $time_namelookup / $total_lines;
my $avg_connect       = $time_connect / $total_lines;
my $avg_appconnect    = $time_appconnect / $total_lines;
my $avg_pretransfer   = $time_pretransfer / $total_lines;
my $avg_redirect      = $time_redirect / $total_lines;
my $avg_starttransfer = $time_starttransfer / $total_lines;
my $avg_total         = $time_total / $total_lines;
my $http_code_str     = "";

for my $key ( keys %http_codes ) {
    $http_code_str .= "$key*$http_codes{$key} ";
}

printf(
    "http2 averages:\n"
      . "time_namelookup,time_connect,time_appconnect,time_pretransfer,time_redirect,time_starttransfer,time_total,http_codes_encountered\n"
      . "%-16.10s%-13.10s%-16.10s%-17.10s%-14.10s%-19.10s%-11.10s%s\n",
    $avg_namelookup, $avg_connect,       $avg_appconnect, $avg_pretransfer,
    $avg_redirect,   $avg_starttransfer, $avg_total,      $http_code_str
);

if ( !$ARGV[1] ) {
    exit 0;
}

my $time_namelookup1    = 0;
my $time_connect1       = 0;
my $time_appconnect1    = 0;
my $time_pretransfer1   = 0;
my $time_redirect1      = 0;
my $time_starttransfer1 = 0;
my $time_total1         = 0;
my %http_codes1;

$file = $ARGV[1];
open( $fh, '<', $file ) or die "Can't read file '$file' [$!]\n";
while ( my $line = <$fh> ) {
    my @fields = split( /,/, $line );
    $time_namelookup1    += $fields[0];
    $time_connect1       += $fields[1];
    $time_appconnect1    += $fields[2];
    $time_pretransfer1   += $fields[3];
    $time_redirect1      += $fields[4];
    $time_starttransfer1 += $fields[5];
    $time_total1         += $fields[6];

    chomp( $fields[7] );
    if ( $http_codes1{ $fields[7] } ) {
        ++$http_codes1{ $fields[7] };
    }
    else {
        $http_codes1{ $fields[7] } = 1;
    }
}

my $avg_namelookup1    = $time_namelookup1 / $total_lines;
my $avg_connect1       = $time_connect1 / $total_lines;
my $avg_appconnect1    = $time_appconnect1 / $total_lines;
my $avg_pretransfer1   = $time_pretransfer1 / $total_lines;
my $avg_redirect1      = $time_redirect1 / $total_lines;
my $avg_starttransfer1 = $time_starttransfer1 / $total_lines;
my $avg_total1         = $time_total1 / $total_lines;
my $http_code1_str     = "";

for my $key ( keys %http_codes1 ) {
    $http_code1_str .= "$key*$http_codes1{$key} ";
}

printf(
    "\nhttp3 averages:\n"
      . "time_namelookup,time_connect,time_appconnect,time_pretransfer,time_redirect,time_starttransfer,time_total,http_codes_encountered\n"
      . "%-16.10s%-13.10s%-16.10s%-17.10s%-14.10s%-19.10s%-11.10s%s\n",
    $avg_namelookup1,  $avg_connect1,  $avg_appconnect1,
    $avg_pretransfer1, $avg_redirect1, $avg_starttransfer1,
    $avg_total1,       $http_code1_str
);

my $time_namelookup_pct =
    $time_namelookup > $time_namelookup1
  ? $time_namelookup - $time_namelookup1 / $time_namelookup * 100
  : abs(
    ( $time_namelookup - $time_namelookup1 / $time_namelookup * 100 ) + 100 );
my $total_connect = $time_connect + $time_appconnect;
printf(
    "\naverage improvements/regressions:\n"
      . "time_namelookup,time_connect,time_appconnect,time_pretransfer,time_redirect,time_starttransfer,time_total\n"
      . "%-16.10s%-13.10s%-16.10s%-17.10s%-14.10s%-19.10s%-11.10s\n\n"
      . "In terms of percentages (a decrease in time is better):\n"
      . "%-16.10s%-13.10s%-16.10s%-17.10s%-14.10s%-19.10s%-11.10s\n",
    ( $time_namelookup - $time_namelookup1 ) / $total_lines,
    ( $total_connect - $time_connect1 ) / $total_lines,
    0,
    ( $time_pretransfer - $time_pretransfer1 ) / $total_lines,
    ( $time_redirect - $time_redirect1 ) / $total_lines,
    ( $time_starttransfer - $time_starttransfer1 ) / $total_lines,
    ( $time_total - $time_total1 ) / $total_lines,
    $time_namelookup_pct,
    $total_connect - $time_connect1 / $total_connect * 100,
    0,
    $time_pretransfer - $time_pretransfer1 / $time_pretransfer * 100,
    $time_redirect - $time_redirect1,
    $time_starttransfer - $time_starttransfer1 / $time_starttransfer * 100,
    $time_total - $time_total1 / $time_total * 100
);

