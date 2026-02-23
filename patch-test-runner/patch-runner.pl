# @author SATO Kentaro
# @license BSD-2-Clause

use v5.30;
use warnings FATAL => qw(numeric syntax uninitialized);
use utf8;
use Getopt::Long 2.33 ();
use Fcntl qw(:seek);

exit 2 if (!Getopt::Long::Parser->new(config => [qw(bundling no_getopt_compat)])->getoptions(
));

use constant PATCHED_SIG => '/* PATCHED af7c94b0-88d5-4134-8ad2-3db770a96d9d */';

foreach my $filePath (@ARGV) {
	open(my $fh, '+<:raw', $filePath) or die "$filePath: $!";
	my $script = do { local $/ = undef; <$fh> };
	next if (index($script, '$start_time = hrtime(true);') != -1); # 8.4+
	next if (rindex($script, PATCHED_SIG, 1024) != -1);
	$script =~
		s{\$start_time = time\(\);\K}
		{ \$start_time_hr = hrtime(true);}ag or next;
	$script =~
		s{(?=\$end_time = time\(\);)}
		{\$end_time_hr = hrtime(true); }ag or next;
	$script =~
		s{function (?:main|get_summary)\(.+?\{\K}
		{\nglobal \$start_time_hr, \$end_time_hr;\n}asmg or next;
	$script =~
		s{^Time taken\s*:\s*' . sprintf\(\K'%[45]d seconds', \$end_time - \$start_time(?=\))}
		{'%.3f seconds', (\$end_time_hr - \$start_time_hr) / 1e9}am or next;
	$script =~
		s{<\?php.*\K}
		{' ' . PATCHED_SIG}e;
	seek($fh, 0, SEEK_SET);
	truncate($fh, 0);
	print $fh $script;
	close($fh);
	say "Patched: $filePath";
}
