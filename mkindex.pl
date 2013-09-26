#!/usr/bin/perl
use strict;
use warnings;

use PDF::API2;
use Encode;
use File::Temp qw(tempdir);
use File::Basename;
use File::Spec::Functions qw(catfile);
use Date::Parse qw(strptime);
use FindBin;
use open qw{:encoding(UTF-8) :std};
use Storable qw(freeze thaw);
use POSIX ":sys_wait_h";

sub get_pdfinfo {
    my ($fn) = @_;

    pipe (my $rfh, my $wfh) or die "pipe(): $!";
    my $pid = fork();

    if (!$pid) {
        # CHILD
        close $rfh;

        my $pdf = PDF::API2->open($fn);

        my %info = $pdf->info;
        my ($author, $date, $title, $tags) = @info{qw(Author CreationDate Title Keywords)};
        my $pages = $pdf->pages();
        
        s/&#0;//g foreach ($title, $tags);

        $author ||= "Unknown";
        $date = do {
            if ($date =~ /D:(\d{4})(\d{2})(\d{2})/) {
                "$1-$2-$3";
            } elsif ($date =~ /^[A-Z][a-z]{2}\s/) {
                my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($date);
                sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);
            } else {
                "1970-01-01";
            }
        };

        print $wfh freeze(
            { author => $author,
             date   => $date,
             title  => $title,
             tags   => $tags,
             pages  => $pages,
           }) or die "print to pipe: $!";

        close $wfh or die "close pipe: $!";
        exit 0;
    }

    # PARENT
    close $wfh;
    my $ret = thaw(do { local $/; <$rfh> });
    close $rfh or die "close pipe: $!";
    if ((my $wp = waitpid($pid, 0)) <= 0 || !WIFEXITED($?) || WEXITSTATUS($?) != 0) {
        die "PDF::API2 child: waitpid($pid, 0) = $wp, status = $?";
    }

    return $ret;
}

sub make_previews {
    my ($outdir, $infile) = @_;
    my $fn = basename($infile);
    unless(-e catfile($outdir, ($fn."-000.png"))) {
        system("convert", "-thumbnail", "x175", $infile, catfile($outdir, $fn.'-%03d.png'));
    }
    return [sort glob(catfile($outdir, $fn.'-???.png'))];
}

my $previewdir = "previews";
-d $previewdir or die "$previewdir does not exist";

my @pdfs = @ARGV ? @ARGV : glob("????.pdf");

print STDERR "Updating index.{html,txt}...\n";

my %pdfs = map {
    $_ => {
        path => $_,
        info => get_pdfinfo($_),
        previews => make_previews($previewdir, $_),
    }
} @pdfs;

open(my $html, ">", "index.html") or die "index.html: $!";
open(my $text, ">", "index.txt")  or die "index.txt: $!";

print $html "<html><body><table border>\n";
print $html "<tr><th>Filename</th><th>Date</th><th>Author</th><th>Title</th><th>Preview</th><th>Tags</th></tr>\n";

foreach my $pdf (map  { $pdfs{$_} }
                 sort { $pdfs{$b}->{info}->{date} cmp
                        $pdfs{$a}->{info}->{date} ||
                        $b cmp $a } # newest on top
                 keys %pdfs) {
    local $SIG{__WARN__} = sub { warn "$pdf->{path}: @_" };
    print $html qq! <tr><td valign="top"><a href="$pdf->{path}">@{[basename($pdf->{path})]}</a></td><td valign="top">$pdf->{info}->{date}</td></td><td valign="top">$pdf->{info}->{author}</td><td width="200px" valign="top">$pdf->{info}->{title}</td><td width="600px" valign="top">\n!;
    print $html qq!  <img src="$_">\n! foreach @{$pdf->{previews}};
    print $html qq! </td><td valign="top">$pdf->{info}->{tags}</td></tr>\n!;

    print $text "@{[basename($pdf->{path})]}\t$pdf->{info}->{pages}\t$pdf->{info}->{date}\t$pdf->{info}->{author}\t$pdf->{info}->{title}\t$pdf->{info}->{tags}\n";
}
print $html "</table></body></html>\n";
close $text;
close $html;

print STDERR "Updating recoll database...\n";
exec(catfile($FindBin::Bin, "rr"), "-i");
