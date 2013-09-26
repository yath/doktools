#!/usr/bin/perl
use strict;
use warnings;
use 5.12.0;
use List::Util qw(sum max);

sub histcat {
    my $pages = $_[0];
#    return $pages > 20 ? ">20" : sprintf("% 3d",$pages);
    return $pages > 9 ? ">9" : " ".$pages+0;
}

sub drawhist {
    my $data = $_[0];
    my $tot = sum(values $data);
    my $catwidth = max(map { length } values $data);
    my %pct;
    foreach my $cat (keys $data) {
        my $docs = $data->{$cat};
        my $pct = $docs / $tot * 100;
        $pct{$cat} = $pct;
    }
    my $pctwidth = max(values %pct);

    foreach my $cat (sort keys %pct) {
#        say "pct: ".$pct{$cat}.", len: ".length($pct{$cat}+0);
        say sprintf('%*s  %-*s [%.1f%%]%s%d', $catwidth, $cat,
            $pctwidth, "*"x$pct{$cat}, $pct{$cat},
            " "x(6-length(sprintf("%.1f", $pct{$cat}))), $data->{$cat});
    }
}

my %pages;
open (my $index, "<index.txt") or die "Unable to open index.txt: $!";
while (<$index>) {
    /^(\d{4}\.pdf)\t(\d+)\t/ or die;
    $pages{$1} = $2;
}
close $index;

my $totaldocs = keys %pages;
my $totalpages = sum values %pages;
my $avgpages = $totalpages / $totaldocs;

say "Total number of documents: $totaldocs";
say "Total number of pages: $totalpages";
say "Average number of pages per document: ".sprintf("%.2f", $avgpages);
say "";
say "Number of pages per document:";
my %histval;
foreach my $pages (values %pages) {
    $histval{histcat($pages)}++;
}
drawhist \%histval;

#use Data::Dumper; print Dumper \%histval;
