# @author SATO Kentaro
# @license BSD-2-Clause

use v5.30;
use warnings FATAL => qw(numeric syntax uninitialized);
use utf8;
use Getopt::Long 2.33 ();
use JSON qw(encode_json);

exit 2 if (!Getopt::Long::Parser->new(config => [qw(bundling no_getopt_compat)])->getoptions(
	'id=s' => \my $id,
	'o=s' => \my $path,
	'outcome=s' => \my $outcome,
));

$id //= 'unknown';
$path //= "result-$id.json";

my $log = do { local $/; <STDIN> };
my %result = (
	id => $id,
	outcome => $outcome,
	log => $log,
);

open(my $fh, '>', $path) or die $!;
print $fh encode_json(\%result);
