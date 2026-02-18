# @author SATO Kentaro
# @license BSD-2-Clause

use v5.30;
use warnings FATAL => qw(numeric syntax uninitialized);
use utf8;
use Getopt::Long 2.33 ();
use List::Util qw(sum);
use JSON qw(decode_json);

exit 2 if (!Getopt::Long::Parser->new(config => [qw(bundling no_getopt_compat)])->getoptions(
));

my $metricPat = qr/Number of tests|Tests \w+|Expected \w+|Time taken/a;
use constant {
	T_COUNT => 'Number of tests',
	T_PASSED => 'Tests passed',
	T_SKIPPED => 'Tests skipped',
	T_WARNED => 'Tests warned',
	T_FAILED => 'Tests failed',
	T_BORKED => 'Tests borked',
	T_EXPECTED => 'Expected fail',
	T_LEAKED => 'Tests leaked',
	T_TIME => 'Time taken',
};

my @files = @ARGV;
my @metrics = (T_COUNT, T_PASSED, T_SKIPPED, T_WARNED, T_FAILED, T_BORKED, T_EXPECTED, T_LEAKED, T_TIME);

say "### 📊 Combined Test Report";
say "";
say "| ID | 🧪 | " . join(" | ", map { getMetricTitle($_) } @metrics) . " |";
say "|:---| --- | " . join("|", ("---:") x scalar @metrics) . "|";

my (@failedIds, @allDetails);
for my $f (@files) {
	open my $fh, "<", $f;
	my $data = decode_json(do { local $/; <$fh> });
	my %result = parseLog($data->{log});
	my $id = $data->{id} // 'ID missing';
	my $t = $result{tests};
	my $row = "| $id | ";
	my $passed = (($data->{outcome} // '') eq 'success') && $t->{+T_COUNT};
	my $total = sum(map { $t->{$_} // 0 } (T_PASSED, T_SKIPPED, T_EXPECTED));
	$passed = $passed && $t->{+T_COUNT} == $total;
	push(@failedIds, $id) if (!$passed);
	$row .= ($passed ? "✔" : ($t->{+T_FAILED} || $t->{+T_BORKED}) ? "❌" : "⚠️") . " | ";
	$row .= join(" | ", map { $t->{$_} // "-" } @metrics);
	$row .= " |\n";
	print $row;
	
	my $details = $result{details};
	if ($details && @$details) {
		my %flags = map { $_ =~ /^([A-Z]+)/ ? ($1 => 1) : () } @$details;
		my $sign = $flags{BORK} || $flags{FAIL} ? "❌" : $flags{XFAIL} ? "⚠️" : "💬";
		push(@allDetails, "#### $sign Non-PASS list: $id");
		push(@allDetails, "```\n" . join("\n", @$details) . "\n```\n");
	} else {
		push(@allDetails, "#### ⚠️ Parse error: $id");
		push(@allDetails, "\nNo details are found.\n");
	}
}
say "\n" . join("\n", @allDetails) if @allDetails;

if (@failedIds) {
	warn "Error: Some tests failed or were not executed.\nTarget IDs: @failedIds\n";
	exit 1;
}
exit;

sub parseLog {
	my ($log) = @_;
	my %result;
	while ($log =~ /\v($metricPat)\s*:\s*([\d.]+)/ag) {
		$result{tests}{$1} = $2;
	}
	if ($log =~ /^TIME START .*?^TIME END /ms) {
		my $testSection = $&;
		# here \v instead of /m; output may contain single \r to rewrite status for console
		my @failures = $testSection =~ /\v((?!(?:TIME|TEST|PASS)\s)[A-Z].+?)(?=\v)/ag;
		$result{details} = \@failures;
	}
	return %result;
}

sub getMetricTitle {
	my ($metric) = @_;
	$metric =~ s/^Tests (\w)/uc($1)/e;
	$metric =~ s/^Expected\b/Exp./;
	$metric = 'Tests' if ($metric eq T_COUNT);
	return $metric;
}
