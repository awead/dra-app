#!/usr/bin/perl
#
# Tom Anderson
# Sun Feb 17 15:45:09 PST 2002
# Sun Mar  3 00:00:43 PST 2002
# Program to evaluate text complexity and spelling.
#
# Copyright Tom Anderson 2002, All rights reserved.
# This program may be copied under the same terms as Perl itself.
# Please send modifications to t@tomacorp.com
#

=pod

 Enhancements Ideas:
   A more verbose option to monitor progress
   Be able to specify an output file
   Be able to use the plain text output and ignore the analysis,
     or maybe send the analysis to STDERR and the plain text
     to STDOUT.
   Maybe there should be options for getting URL or text file 
     - is there a module?
   Handle HTML tables properly 
     (perhaps just remove table tags or use HTML::TableExtract)
   Work as a CGI, as a client for posting.
   Use a module or put file/URL guessing in a subroutine.

=cut

use strict;
use warnings;
use diagnostics;

use Lingua::EN::Fathom;
use Text::FormatTable;
use Math::Round qw(nearest);
use LWP::Simple;
use HTML::TreeBuilder;
use HTML::FormatText;
use Lingua::Ispell qw( :all );
use Data::Dumper;
$Lingua::Ispell::path= "/usr/bin/ispell";
my $VERSION=0.01;
$|++;

my %fog_description = 
    ( 'unreadable' =&gt; [18,1e12], 
      'difficult'  =&gt; [14,18]  ,
      'ideal'      =&gt; [11,14]  ,  
      'acceptable' =&gt; [8,11]   ,
      'childish'   =&gt; [-1e12,8]);

my $file= shift;
die "Usage: $0 file_or_url\n" if not defined $file;

my $query= $file;

my $content;
if (-e $file)
{
  my $slash= $/;
  local undef $/;
  open(IN, $file);
  $content= &lt;IN&gt;;
  close IN;
  $/= $slash;
}
else
{
  $content = get($file);
  if ($content eq "") { die "No content at $file"; }
  $file= "/tmp/html_scan.$$";
  open(TMP, '&gt;'.$file) or die "Can't create temporary html file";
  print TMP $content;
  close TMP;
}

# If the content is HTML, format it as plain text first.
my $content_type="plain text";
if ($query =~ /.htm$/i or $query =~ /.html$/i or $content =~ /&lt;html/i)
{
  $content_type="HTML";
  $content =~ s/&lt;table//g;
  $content =~ s/&lt;TABLE//g;
  # print STDERR $content;
  my $tree = HTML::TreeBuilder-&gt;new_from_content($content);
  # my $tree = HTML::TreeBuilder-&gt;new-&gt;parse_file($file);
  my $formatter = HTML::FormatText-&gt;new(leftmargin =&gt; 0, rightmargin =&gt; 78);

  $file= "/tmp/txt_scan.$$";
  open(TMP, '&gt;'.$file) or die "Can't create temporary text file";
  print TMP $formatter-&gt;format($tree);
  close TMP;
}

my $text = new Lingua::EN::Fathom;
$text-&gt;analyse_file($file);
 
my $accumulate = 1;
my $text_string= "";
$text-&gt;analyse_block($text_string,$accumulate);
 
my %words = $text-&gt;unique_words;
# my $wordlist= join ' ', sort keys %words;
my @wordlist= sort keys %words;

my $fog     = nearest(0.1, $text-&gt;fog);
my $flesch  = nearest(0.1, $text-&gt;flesch);
my $kincaid = nearest(0.1, $text-&gt;kincaid);

my $table = Text::FormatTable-&gt;new('r  l  l  l');

my $fog_descr;
for (keys %fog_description) 
{
  if ($fog &gt;= $fog_description{$_}[0] and $fog &lt; $fog_description{$_}[1])
  # print Dumper($_),"\n";
  {
    $fog_descr= $_;
  }
}

my $percent_complex_words = nearest(0.1,$text-&gt;percent_complex_words);

$table-&gt;row("Fog", $fog, $fog_descr, "");
$table-&gt;row("Grade Level", $kincaid, "(Flesch-Kincaid)", "");
$table-&gt;row("Flesch", $flesch, "", "");
$table-&gt;row("Complex words", "$percent_complex_words %", "", "");
$table-&gt;row("Chars", $text-&gt;num_chars, "Words", $text-&gt;num_words);
$table-&gt;row("Lines", $text-&gt;num_text_lines, "Blank Lines", $text-&gt;num_blank_lines);
$table-&gt;row("Sentences", $text-&gt;num_sentences, "Paragraphs", $text-&gt;num_paragraphs);

# Break up the wordlist before calling spellcheck since
# spellcheck seems to have trouble with a large input string.

my @missing_words;
my $sublist="";
my $cnt=0;
while (@wordlist &gt; 0)
{
  $sublist .= shift @wordlist;
  if ($cnt &gt; 50)
  {
    for my $r (spellcheck($sublist))
    {
      push @missing_words, $r-&gt;{'term'};
    }
    $sublist="";
    $cnt=0;
  }
  else
  {
    $sublist .= ' ';
    $cnt++;
  }
}

my $colname= "Spelling";
my @cols;
my $col=0;
for ( @missing_words ) 
{
  $cols[$col]= $_;
  if ($col &gt;= 2)
  {
    $table-&gt;row($colname, $cols[0], $cols[1], $cols[2]);
    $col=0;
    $colname="";
  }
  else
  {
    $col++;
  }
}

print "Analysis of $content_type: $query\n", $table-&gt;render();
