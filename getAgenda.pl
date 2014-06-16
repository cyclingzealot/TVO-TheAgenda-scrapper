#!usr/bin/perl

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTML::LinkExtor; # allows you to extract the links off of an HTML page.
use XML::Parser;
use Data::Dumper;
use XML::Simple;

##### LOCK CODE
use warnings;
use Fcntl qw(:flock);
$lockfile = $ENV{"HOME"} . '/.getTheAgenda/lockFile';
sub BailOut {
    print "$0 is already running. Exiting.\n";
	print "(File '$lockfile' is locked).\n";
	exit(1);
}
open($fhpid, '>', $lockfile) or die "error: open '$lockfile': $!";
flock($fhpid, LOCK_EX|LOCK_NB) or BailOut();
#### END LOCK CODE


$debug = 0;
$dlfp = $downloadedListFilePath = $ENV{"HOME"} . '/.getTheAgenda/downloadedurls';
$videoDir = $ARGV[0];
if(!-e $videoDir)  {
	if($debug)  {print @ARGV;}
	print("getAgenda.pl \$videoDir \$maxSize \$topSpeed\n\n");
	exit();
};
$maxSize = $ARGV[1];
if(!$maxSize)  {$maxSize=500}
if($maxSize < 1)  {die("Maximum size must be at least 1 MB")};
$topSpeed = $ARGV[2];
if(!$topSpeed)  {$topSpeed=40880}  #The agenda will produce about 5 GBs in a month.  This is to be able to download 10 GBs/month
				  #Other suggested size: 40880 for 100 GBs/month
$stopFile = '/tmp/stopGetAgenda';

@downloadedList;
if (-e $dlfp) {
	open(DOWNLOADEDFP, "<$dlfp");
	@downloadedList = <DOWNLOADEDFP>;
	close(DOWNLOADEDFP);
}


print "Done loading\n";

$URL = 'http://feeds.tvo.org/tvo/TxZN';


$browser = LWP::UserAgent->new();
$browser->timeout(100);

print "Fetching content...\n";
my $request = HTTP::Request->new(GET => $URL);
my $response = $browser->request($request);
if ($response->is_error()) {printf "%s\n", $response->status_line;}
$contents = $response->content();

print "Got content.  Now parsing....\n";
#create object
$xml = new XML::Simple;

#read XML file
$data = $xml->XMLin($contents);
print "Content parsed. \n";


&manageFiles($videoDir, $maxSize);



# Open download list for writting
open(DOWNLOADEDFP, ">>$dlfp") or die("Unable to open downloaded list file ($dlfp) for writting.  OS error: \n $! \n");

foreach $entry (@{$data->{channel}->{item}}) {

	$fileName = $title = $entry->{title}; chomp($title);
	$url = $entry->{'media:content'}->{url}; chomp($url);
	if(!$url)  {$url = $entry->{enclosure}->{url};}
	if ($debug)  {print $title . "\n" . $url . "\n";}
	
	if (!grep /^$url$/, @downloadedList) {
		if($debug)  {print "$url not in $dlfp";}

		$fileName =~ s/[^a-zA-Z0-9]//g;

		$filePath = $videoDir . '/' . $fileName . '.m4v';
		chomp($filePath);
		
		$pubDate = $entry->{pubDate};
		$pubDate = `echo $pubDate | cut -d ' ' -f 1-5`;
		chomp($pubDate);
		
		print "Saving $title\n";
		print "url: $url\n";
		print "file: $filePath\n";
		print "pubDate: $pubDate\n";
		print "maxSpeed (b/s): $topSpeed\n";
		if(-e $stopFile)  {
			system ("rm -vf $stopFile");
			die("Stop file $stopFile is present.  Removed for next session.");
		}
		else  {print "To stop downloading at next file use: \n'touch $stopFile'\n";}
		print "\n";
		system ("wget --limit-rate=$topSpeed -O $filePath '$url'");
			if($? == 0) {print DOWNLOADEDFP $url . "\n";}
			else {print "\nwget returned $? .  Not adding url $url in succesfully downloaded list of files $dlfp.\n";}
		system ("touch -d '$pubDate' $filePath");
		print "Done with $title\n";

		print "\n\n\n";

		&manageFiles($videoDir, $maxSize);
	}

}
#print Dumper($data->{channel});
#
#
#close downloaded url list
close(DOWNLOADEDFP);

print "Done.\n";




sub manageFiles
{
	$videoDirSizeMB = `du -m $videoDir | awk '{print \$1}'`;
	chomp($videoDirSizeMB);

	print "Size of $videoDir is $videoDirSizeMB MBs with a limit of $maxSize MBs.\n";

	if("$videoDirSizeMB" <= "$maxSize") {
		print "Not deleting anything \n";
	}
	else {
		print "Deleting files, starting with oldest\n";
		while(!("$videoDirSizeMB" <= "$maxSize")) {
			$oldestFileName = `ls -t $videoDir | tail -n 1`;
			if(!$videoDir)  {die("videoDir variable is empty.  Please contact a programmer.\n")};
			$filePath = $videoDir . '/' . $oldestFileName;
			system ("rm -fv $filePath");
			$videoDirSizeMB = `du -m $videoDir | awk '{print \$1}'`;
		}
		
	}

}
