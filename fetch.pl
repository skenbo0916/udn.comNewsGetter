#!/usr/bin/perl

use strict;
BEGIN {
    use getCpanModule;
    getCpanModule::loadCpanModule( 'WWW', 'Mechanize', 'http://cpansearch.perl.org/src/ETHER/WWW-Mechanize-1.74/lib/WWW/Mechanize.pm' );
}

use WWW::Mechanize;
use Getopt::Std;
use LWP::Simple;
use Encode qw/decode encode/;
use URI::Escape qw/uri_escape uri_unescape/;

our $CONFIG = do 'fetchConfigs.pm';

sub googleSearchUriGenerator {
    my( $searchKeyword, $month, $start ) = @_;

    #一字不差&tbs=li:1
    #tbs=cdr:1,cd_min:2014/1/1,cd_max:2014/12/31,sbd:1

    "https://www.google.com.tw/search?".
    "q=$searchKeyword ".
    "site:$CONFIG->{searchSite}&".
    "tbs=cdr:1,".
    "cd_min:$CONFIG->{searchYear}/$month/1,".
    "cd_max:$CONFIG->{searchYear}/$month/31,".
    "sbd:1&".
    "start=$start";
}

sub uriRefiner {
    my( $rawUri, $keyword ) = @_;

    $rawUri =~ s/^\/url\?q=//;
    $rawUri = uri_unescape( $rawUri );
    $rawUri =~ s/cache:(?:\w+)://;
    $rawUri =~ s/&sa=(\S+)//;
    $rawUri =~ s/&hl=(\S+)//;
    $rawUri =~ s/&ct=(\S+)//;
    $rawUri =~ s/&tbs=(\S+)//;
    my $originalSearchString = uri_escape( $keyword ) . "+site:$CONFIG->{searchSite}";
    $rawUri =~ s/$originalSearchString//;

    $rawUri;
}

sub mech {
    my( $uri ) = @_;

    my $mech = WWW::Mechanize->new( onerror => undef, onwarn => \&Carp::carp, );
    $mech->add_header( 'accept-Language' => 'zh-TW,zh;q=0.8,en-US;q=0.6,en;q=0.4' );
    $mech->add_header( 'accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' );
    $mech->add_header( 'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.76 Safari/537.36' );

    $mech->get( $uri );

    $mech->links;
}

sub googleSearch {
    my( $uri, $keyword ) = @_;

    my $googleSearchResultList = [];

    my $keywordUtf8 = decode( 'utf8', $keyword );

    for my $eachGoogleSearchTerm ( mech( $uri ) ) {
	next unless $eachGoogleSearchTerm->[1] =~ /$keywordUtf8/;
	next unless $eachGoogleSearchTerm->[0] =~ /http:\/\/(?:\S*)udn\.com/;

	push @$googleSearchResultList, {
	    'title' => $eachGoogleSearchTerm->[1],
	    'uri' => uriRefiner( $eachGoogleSearchTerm->[0], $keyword ),
	};
    }

    $googleSearchResultList;
}

sub targetSiteContentParser {
    my( $rawHtml, $requestedUri ) = @_;

    if( $requestedUri =~ /\.shtml/ ) {
	eval {
	    $rawHtml = encode(
		"utf-8", decode(
		    "Big5", get( $requestedUri )
		)
	    );
	};
    }
    $rawHtml =~ s/(?:\n|\r| )//g;
    my( $content ) = $rawHtml =~ /(<p>.*?<\/p>)/;
    $content =~ s/<(?:.*?)>//g;

    $content;
}

sub storeThePage {
    my( $month, $article ) = @_;

    print "uri: $article->{uri}\ntitle: $article->{title}\n";
    open FH, ">>$CONFIG->{searchKeyword}/$month/".encode( 'utf-8', $article->{title} ).".txt" or close FH;
    print FH "$article->{uri}\n$article->{content}";
    close FH;
}	

sub usage {
    (
     "usage: $0 [-h] [-k searchKeyword]\n".
     "\t-h show this manual\n".
     "\t-k [keyword]\n"
    );
}

sub main {

    my %option = ();
    getopts( "hk:", \%option );
    die usage if $option{h};
    die 'no search keyword' unless $option{k};

    $CONFIG->{searchKeyword} = $option{k};
    print "search: $CONFIG->{searchKeyword}\n";

    `mkdir $CONFIG->{searchKeyword}`;

    for( my $month = 2; $month <= 2; $month++ ) {
	`mkdir $CONFIG->{searchKeyword}/$month`;

	for( my $start = $CONFIG->{startTerm}; ; $start += $CONFIG->{searchPerPage} ) {

	    print "start: $start\n";

	    my $googleSearchUri = googleSearchUriGenerator( $CONFIG->{searchKeyword}, $month, $start );
	    sleep $CONFIG->{minDelaySrcondsPerSearch} + rand( $CONFIG->{MAXDelaySrcondsPerSearch} - $CONFIG->{minDelaySrcondsPerSearch} );

	    my $googleSearchResultList = googleSearch( $googleSearchUri, $CONFIG->{searchKeyword} );

	    exit unless --$CONFIG->{MAXemptyTimes} || @$googleSearchResultList;

	    for my $eachResult ( @$googleSearchResultList ) {
		my $rawHtml = get( $eachResult->{uri} );
		my $content = targetSiteContentParser( $rawHtml, $eachResult->{uri} );

		storeThePage( $month, {
		    title => $eachResult->{title},
		    uri => $eachResult->{uri},
		    content => $content,
		} );
	    }
	}
    }

}

main();

1;
