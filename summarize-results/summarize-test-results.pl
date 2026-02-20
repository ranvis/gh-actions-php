# @author SATO Kentaro
# @license BSD-2-Clause

use v5.30;
use warnings FATAL => qw(numeric syntax uninitialized);
use utf8;
use Getopt::Long 2.33 ();
use JSON qw(decode_json);
use List::Util qw(uniqstr sum sum0);

exit 2 if (!Getopt::Long::Parser->new(config => [qw(bundling no_getopt_compat)])->getoptions(
	'glob!' => \my $glob,
));

my $metricPat = qr/Number of tests|Tests \w+|Expected \w+|Time taken/a;
use constant {
	T_COUNT => 'Number of tests',
	T_PASSED => 'Tests passed',
	T_SKIPPED => 'Tests skipped',
	T_WARNED => 'Tests warned',
	T_FAILED => 'Tests failed',
	T_BORKED => 'Tests borked',
	T_XFAIL => 'Expected fail',
	T_LEAKED => 'Tests leaked',
	T_TIME => 'Time taken',
};
my %metricTitle = (
	T_COUNT, 'Total',
	T_PASSED, 'Pass',
	T_SKIPPED, 'Skip',
	T_WARNED, 'Warn',
	T_FAILED, 'Fail',
	T_BORKED, 'Bork',
	T_XFAIL, 'XFail',
	T_LEAKED, 'Leak',
	T_TIME, 'Time',
);

my @filePaths = uniqstr @ARGV;
@filePaths = uniqstr map { glob(qq{"$_"}) } @filePaths if ($glob);
my @metrics = (T_COUNT, T_PASSED, T_SKIPPED, T_WARNED, T_FAILED, T_BORKED, T_XFAIL, T_LEAKED, T_TIME);

say "### 📊 Combined Test Report";
say "";
say mdTable("ID", "🧪", map { $metricTitle{$_} // $_ } @metrics);
say mdTable(':---', '---', ("---:") x scalar @metrics, {pad => 0});

my (@failedIds, @allDetails);
for my $filePath (@filePaths) {
	open(my $fh, '<', $filePath) or do {
		warn "$filePath: $!";
		next;
	};
	my $data = decode_json(do { local $/; <$fh> });
	my %result = parseLog($data->{log});
	my $id = $data->{id} // 'ID missing';
	my $t = $result{tests};
	my $passed = (($data->{outcome} // '') eq 'success') && $t->{+T_COUNT};
	my $total = sum(map { $t->{$_} // 0 } (T_PASSED, T_SKIPPED, T_XFAIL));
	$passed = $passed && $t->{+T_COUNT} == $total;
	push(@failedIds, $id) if (!$passed);
	my @row = (
		$id,
		$passed ? "✔" : ($t->{+T_FAILED} || $t->{+T_BORKED}) ? "❌" : "⚠️",
		map { $t->{$_} || "-" } @metrics,
	);
	say mdTable(@row);

	my $details = $result{details};
	if ($details && @$details) {
		my %flags = map { $_ =~ /^([A-Z]+)/ ? ($1 => 1) : () } @$details;
		my $sign = ($flags{BORK} || $flags{FAIL}) ? "❌" : $flags{XFAIL} ? "⚠️" : "💬";
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

sub mdTable {
	return "| " . join(" | ", @_) . " |";
}

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

sub mdTable {
	my (@cells) = @_;
	return "" if (!@cells);
	my %opt = do {
		if (ref $cells[$#cells]) {
			pop(@cells)->%*;
		} else { () }
	};
	@cells = map { " $_ " } @cells if ($opt{pad} // 1);
	return "|" . join("|", @cells) . "|";
}
