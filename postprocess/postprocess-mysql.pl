#! /usr/bin/perl

#
# LPCPU (Linux Performance Customer Profiler Utility): ./postprocess/postprocess-mysql.pl
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

#
#  Usage: postprocess-mysql.pl WORKING_DIR  RUN_ID
#
#         WORKING_DIR       Directory that contains the "mysql-profiler.NNN" profile data directory
#         RUN_ID            The run identifier (NNN) used for the mysql profiler directories

use autobench::jschart;

### Main processing

die("postprocess-mysql: No working directory specified\n") if (@ARGV < 1);
die("postprocess-mysql: No identifier specified\n")        if (@ARGV < 2);

my $mysql_dir = "$ARGV[0]";
my $run_id    = "$ARGV[1]";

my $mysql_profiler  = "$mysql_dir/mysql-profiler.$run_id";
my $mysql_breakout  = "$mysql_dir/mysql-breakout.$run_id";
my $mysql_processed = "$mysql_dir/mysql-processed.$run_id";
my $mysql_plotfiles = "$mysql_processed/plot-files";

-d $mysql_profiler     || die("postprocess-mysql: Profiler directory does not exist: $mysql_profiler\n");
mkdir $mysql_breakout  || die("postprocess-mysql: Unable to create directory $mysql_breakout: $!\n");
mkdir $mysql_processed || die("postprocess-mysql: Unable to create directory $mysql_processed: $!\n");
mkdir $mysql_plotfiles || die("postprocess-mysql: Unable to create directory $mysql_plotfiles: $!\n");


my $file;
my $time, $interval = 1;

# Capture some variables
my $key_buffer_size, $key_cache_block_size;
my $max_connections;
my $qcache_size, $qcache_min_res_unit;
my $table_cache_size, $thread_cache_size;
open(VARS, "< $mysql_profiler/variables") || die("postprocess-mysql: Unable to open $mysql_profiler/variables: $!\n");
while (<VARS>) {
	if (/^key_buffer_size\s(\d*)/) {
		$key_buffer_size = $1;
	}
	elsif (/^key_cache_block_size\s(\d*)/) {
		$key_cache_block_size = $1;
	}
	elsif (/^max_connections\s(\d*)/) {
		$max_connections = $1;
	}
	elsif (/^query_cache_min_res_unit\s(\d*)/) {
		$qcache_min_res_unit = $1;
	}
	elsif (/^query_cache_size\s(\d*)/) {
		$qcache_size = $1;
	}
	elsif (/^table_cache\s(\d*)/ || /^table_open_cache\s(\d*)/) {
		$table_cache_size = $1;
	}
	elsif (/^thread_cache_size\s(\d*)/) {
		$thread_cache_size = $1;
	}
}
close VARS;

my $last_time;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);
	if (defined($last_time)) {
		$interval = $time - $last_time;
		last;
	}
	$last_time = $time;
}

my $first_stats;

# Query breakdown
my $total_queries, $total_questions, $total_qcaches, $total_selects, $total_inserts, $total_updates, $total_deletes;
my $queries, $questions, $qcaches, $selects, $inserts, $updates, $deletes;
my $use_queries = 0;
open(BREAKOUT, "> $mysql_breakout/breakout.queries") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.queries: $!\n");
print BREAKOUT "#Time\tQueries\tQcache\tSelects\tInserts\tUpdates\tDeletes\n";
print BREAKOUT "#    \t       \tHits  \t       \t       \t       \t       \n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Queries\s+(\d*)/) {
			$use_queries = 1;
			$queries = defined($total_queries) ? $1 - $total_queries : 0;
			$queries = $queries / $interval;
			$total_queries = $1;
		}
		elsif (/^Questions\s+(\d*)/) {
			$questions = defined($total_questions) ? $1 - $total_questions : 0;
			$questions = $questions / $interval;
			$total_questions = $1;
		}
		elsif (/^Qcache_hits\s+(\d*)/) {
			$qcaches = defined($total_qcaches) ? $1 - $total_qcaches : 0;
			$qcaches = $qcaches / $interval;
			$total_qcaches = $1;
		}
		elsif (/^Com_select\s+(\d*)/) {
			$selects = defined($total_selects) ? $1 - $total_selects : 0;
			$selects = $selects / $interval;
			$total_selects = $1;
		}
		elsif (/^Com_insert\s+(\d*)/) {
			$inserts = defined($total_inserts) ? $1 - $total_inserts : 0;
			$inserts = $inserts / $interval;
			$total_inserts = $1;
		}
		elsif (/^Com_update\s+(\d*)/) {
			$updates = defined($total_updates) ? $1 - $total_updates : 0;
			$updates = $updates / $interval;
			$total_updates = $1;
		}
		elsif (/^Com_delete\s+(\d*)/) {
			$deletes = defined($total_deletes) ? $1 - $total_deletes : 0;
			$deletes = $deletes / $interval;
			$total_deletes = $1;
		}
	}
	close STATS;

	$queries = $questions if (!$use_queries);
	printf BREAKOUT "$time\t%d\t%d\t%d\t%d\t%d\t%d\n", $queries, $qcaches, $selects, $inserts, $updates, $deletes if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;


# Connection tracking
my $active_connections, $max_used_connections;
open(BREAKOUT, "> $mysql_breakout/breakout.connections") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.connections: $!\n");
print BREAKOUT "#Time\tActive\tMax\tLimit\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Threads_connected\s+(\d*)/) {
			$active_connections = $1;
		}
		elsif (/^Max_used_connections\s(\d*)/) {
			$max_used_connections = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\t%d\t%d\n", $active_connections, $max_used_connections, $max_connections;
}
close BREAKOUT;

# Thread tracking
my $threads_cached, $threads_created, $threads_running;
open(BREAKOUT, "> $mysql_breakout/breakout.threads") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.threads: $!\n");
print BREAKOUT "#Time\tCache\tCached\tCreated\tRunnings\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Threads_cached\s+(\d*)/) {
			$threads_cached = $1;
		}
		elsif (/^Threads_created\s+(\d*)/) {
			$threads_created = $1;
		}
		elsif (/^Threads_running\s+(\d*)/) {
			$threads_running = $1;
		}
	}
	close STATS;

	print BREAKOUT "$time\t$thread_cache_size\t$threads_cached\t$threads_created\t$threads_running\n";
}
close BREAKOUT;

# Table cache
my $open_tables, $opened_tables;
open(BREAKOUT, "> $mysql_breakout/breakout.tables") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.tables: $!\n");
print BREAKOUT "#Time\tCache\tOpen\tOpened\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Open_tables\s+(\d*)/) {
			$open_tables = $1;
		}
		elsif (/^Opened_tables\s+(\d*)/) {
			$opened_tables = $1;
		}
	}
	close STATS;

	print BREAKOUT "$time\t$table_cache_size\t$open_tables\t$opened_tables\n";
}
close BREAKOUT;

# Temporary tables
my $total_tmp_tables, $total_tmp_disk_tables;
my $tmp_tables, $tmp_disk_tables;
open(BREAKOUT, "> $mysql_breakout/breakout.temp_tables") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.temp_tables: $!\n");
print BREAKOUT "#Time\tTemp\tTempDisk\n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Created_tmp_tables\s+(\d*)/) {
			$tmp_tables = defined($total_tmp_tables) ? $1 - $total_tmp_tables : 0;
			$tmp_tables = $tmp_tables / $interval;
			$total_tmp_tables = $1;
		}
		elsif (/^Created_tmp_disk_tables\s+(\d*)/) {
			$tmp_disk_tables = defined($total_tmp_disk_tables) ? $1 - $total_tmp_disk_tables : 0;
			$tmp_disk_tables = $tmp_disk_tables / $interval;
			$total_tmp_disk_tables = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\t%d\n", $tmp_tables, $tmp_disk_tables if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;

# Key cache
my $key_read_requests, $key_reads, $key_ratio;
my $key_ratio_target = .1;
open(BREAKOUT, "> $mysql_breakout/breakout.key_cache") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.key_cache: $!\n");
print BREAKOUT "#Time\tRatio\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Key_read_requests\s+(\d*)/) {
			$key_read_requests = $1;
		}
		elsif (/^Key_reads\s+(\d*)/) {
			$key_reads = $1;
		}
	}
	close STATS;

	$key_ratio = ($key_read_requests > 0) ? $key_reads / $key_read_requests : ($key_reads > 0) ? 1 : 0;
	printf BREAKOUT "$time\t%.4f\t%.4f\n", $key_ratio, $key_ratio_target;
}
close BREAKOUT;

# Key buffer
my $key_blocks_unused, $key_buffer_usage;
open(BREAKOUT, "> $mysql_breakout/breakout.key_buffer") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.key_buffer: $!\n");
print BREAKOUT "#Time\tIn Use\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	if ($key_buffer_size > 0) {
		next unless open(STATS, "< $file");
		while (<STATS>) {
			if (/^Key_blocks_unused\s+(\d*)/) {
				$key_blocks_unused = $1;
			}
		}
		close STATS;

		$key_buffer_usage = (1 - (($key_blocks_unused * $key_cache_block_size) / $key_buffer_size)) * 100;
	}
	else {
		$key_buffer_usage = 0;
	}

	printf BREAKOUT "$time\t%d\n", $key_buffer_usage;
}
close BREAKOUT;

# Query cache efficiency
my $qcache_hits, $com_select, $qcache_ratio;
open(BREAKOUT, "> $mysql_breakout/breakout.query_cache") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.query_cache: $!\n");
print BREAKOUT "#Time\tHitRate\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Qcache_hits\s+(\d*)/) {
			$qcache_hits = $1;
		}
		elsif (/^Com_select\s+(\d*)/) {
			$com_select = $1;
		}
	}
	close STATS;

	$qcache_ratio = ($qcache_hits > 0) ? ($qcache_hits / ($qcache_hits + $com_select)) * 100 : 0;
	printf BREAKOUT "$time\t%d\n", $qcache_ratio;
}
close BREAKOUT;

# Query cache overhead
my $qcache_inserts;
open(BREAKOUT, "> $mysql_breakout/breakout.query_cache_ohead") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.query_cache_ohead: $!\n");
print BREAKOUT "#Time\tInsertHitRatio\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Qcache_hits\s+(\d*)/) {
			$qcache_hits = $1;
		}
		elsif (/^Qcache_inserts\s+(\d*)/) {
			$qcache_inserts = $1;
		}
	}
	close STATS;

	$qcache_ratio = (($qcache_hits > 0) && ($qcache_inserts <= $qcache_hits)) ? ($qcache_inserts / $qcache_hits) * 100 : 100;
	printf BREAKOUT "$time\t%d\n", $qcache_ratio;
}
close BREAKOUT;

# Query cache pruning
my $total_qcache_lowmem_prunes;
my $qcache_lowmem_prunes;
open(BREAKOUT, "> $mysql_breakout/breakout.query_cache_prunes") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.query_cache_prunes: $!\n");
print BREAKOUT "#Time\tPrunes\n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Qcache_lowmem_prunes\s+(\d*)/) {
			$qcache_lowmem_prunes = defined($total_qcache_lowmem_prunes) ? $1 - $total_qcache_lowmem_prunes : 0;
			$qcache_lowmem_prunes = $qcache_lowmem_prunes / $interval;
			$total_qcache_lowmem_prunes = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\n", $qcache_lowmem_prunes if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;

# Query cache entry size
my $qcache_free_memory, $qcache_queries_in_cache;
open(BREAKOUT, "> $mysql_breakout/breakout.query_cache_entry_size") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.query_cache_entry_size: $!\n");
print BREAKOUT "#Time\tAllocSize\tAvgSize\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Qcache_free_memory\s+(\d*)/) {
			$qcache_free_memory = $1;
		}
		elsif (/^Qcache_queries_in_cache\s+(\d*)/) {
			$qcache_queries_in_cache = $1;
		}
	}
	close STATS;

	$qcache_ratio = ($qcache_queries_in_cache > 0) ? ($qcache_size - $qcache_free_memory) / $qcache_queries_in_cache : 0;
	printf BREAKOUT "$time\t%d\t%d\n", $qcache_min_res_unit, $qcache_ratio;
}
close BREAKOUT;

# Query cache buffer
my $qcache_free_mem, $qcache_usage;
open(BREAKOUT, "> $mysql_breakout/breakout.query_buffer") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.query_buffer: $!\n");
print BREAKOUT "#Time\tIn Use\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	if ($qcache_size > 0) {
		next unless open(STATS, "< $file");
		while (<STATS>) {
			if (/^Qcache_free_memory\s+(\d*)/) {
				$qcache_free_mem = $1;
			}
		}
		close STATS;

		$qcache_usage = (1 - ($qcache_free_mem / $qcache_size)) * 100;
	}
	else {
		$qcache_usage = 0;
	}

	printf BREAKOUT "$time\t%d\n", $qcache_usage;
}
close BREAKOUT;

# Sort buffer size indicators
my $sort_merge_passes;
open(BREAKOUT, "> $mysql_breakout/breakout.sort_buffer") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.sort_buffer: $!\n");
print BREAKOUT "#Time\tPasses\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Sort_merge_passes\s+(\d*)/) {
			$sort_merge_passes = $1;
		}
	}
	close STATS;

	print BREAKOUT "$time\t$sort_merge_passes\n";
}
close BREAKOUT;

# Read buffer size indicators
my $read_rnd_next, $selects, $table_scan_ratio;
my $table_scan_ratio_target = 4000;
open(BREAKOUT, "> $mysql_breakout/breakout.read_buffer") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.read_buffer: $!\n");
print BREAKOUT "#Time\tScan \n";
print BREAKOUT "#    \tRatio\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Com_select\s+(\d*)/) {
			$selects = $1;
		}
		elsif (/^Handler_read_rnd_next\s+(\d*)/) {
			$read_rnd_next = $1;
		}
	}
	close STATS;

	$table_scan_ratio = ($selects > 0) ? $read_rnd_next / $selects : 0;
	printf BREAKOUT "$time\t%d\t%d\n", $table_scan_ratio, $table_scan_ratio_target;
}
close BREAKOUT;

# Table indexes
my $total_read_key, $total_read_rnd;
my $read_key, $read_rnd;
open(BREAKOUT, "> $mysql_breakout/breakout.table_indexes") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.table_indexes: $!\n");
print BREAKOUT "#Time\tKeyed\tNonKeyed\n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Handler_read_key\s+(\d*)/) {
			$read_key = defined($total_read_key) ? $1 - $total_read_key : 0;
			$read_key = $read_key / $interval;
			$total_read_key = $1;
		}
		elsif (/^Handler_read_rnd\s+(\d*)/) {
			$read_rnd = defined($total_read_rnd) ? $1 - $total_read_rnd : 0;
			$read_rnd = $read_rnd / $interval;
			$total_read_rnd = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\t%d\n", $read_key, $read_rnd if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;

# InnoDB buffer usage
my $pages_data, $pages_free, $pages_total;
open(BREAKOUT, "> $mysql_breakout/breakout.innodb_buffer") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.innodb_buffer: $!\n");
print BREAKOUT "#Time\tTotal\tData\tFree\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Innodb_buffer_pool_pages_data\s+(\d*)/) {
			$pages_data = $1;
		}
		elsif (/^Innodb_buffer_pool_pages_free\s+(\d*)/) {
			$pages_free = $1;
		}
		elsif (/^Innodb_buffer_pool_pages_total\s+(\d*)/) {
			$pages_total = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\t%d\t%d\n", $pages_total, $pages_data, $pages_free;
}
close BREAKOUT;

# InnoDB buffer flushing
my $total_pages_flushed;
my $pages_flushed;
open(BREAKOUT, "> $mysql_breakout/breakout.innodb_buffer_flush") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.innodb_buffer_flush: $!\n");
print BREAKOUT "#Time\tFlushed\n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Innodb_buffer_pool_pages_flushed\s+(\d*)/) {
			$pages_flushed = defined($total_pages_flushed) ? $1 - $total_pages_flushed : 0;
			$pages_flushed = $pages_flushed / $interval;
			$total_pages_flushed = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\n", $pages_flushed if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;

# InnoDB row lock time
my $row_lock_time_avg, $row_lock_time_max;
open(BREAKOUT, "> $mysql_breakout/breakout.innodb_lock_time") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.innodb_lock_time: $!\n");
print BREAKOUT "#Time\tAvg\tMax\n";
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Innodb_row_lock_time_avg\s+(\d*)/) {
			$row_lock_time_avg = $1;
		}
		if (/^Innodb_row_lock_time_max\s+(\d*)/) {
			$row_lock_time_max = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%d\t%d\n", $row_lock_time_avg, $row_lock_time_max;
}
close BREAKOUT;

# InnoDB row lock waits
my $total_row_lock_waits;
my $row_lock_waits;
open(BREAKOUT, "> $mysql_breakout/breakout.innodb_lock_waits") || die("postprocess-mysql: Unable to open $mysql_profiler/breakout.innodb_lock_waits: $!\n");
print BREAKOUT "#Time\tWaits\n";
$first_stats = 1;
foreach $file (glob("$mysql_profiler/status.*")) {
	next unless -f $file;

	($time) = ($file =~ /$mysql_profiler\/status\.(.*)/);

	next unless open(STATS, "< $file");
	while (<STATS>) {
		if (/^Innodb_row_lock_waits\s+(\d*)/) {
			$row_lock_waits = defined($total_row_lock_waits) ? $1 - $total_row_lock_waits : 0;
			$row_lock_waits = $row_lock_waits / $interval;
			$total_row_lock_waits = $1;
		}
	}
	close STATS;

	printf BREAKOUT "$time\t%.1f\n", $row_lock_waits if (!$first_stats);

	# Baselines have been established, start recording results for graphs now
	$first_stats = 0;
}
close BREAKOUT;

if (! $ENV{'FORCE_CHART_PL'}) {
    my $chart_page = new autobench::jschart("MySQL Charts");
    if ($ENV{'FORCE_JSCHART_REMOTE_LIBRARY'}) {
	$chart_page->set_library_remote;
    }

    if (! $ENV{'FORCE_JSCHART_NO_PACKED_PLOTFILES'}) {
	$chart_page->enable_packed_plotfiles($output_directory);
    }

    ## Queries
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_total",   "total",  1, 2);
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_qcaches", "qcache", 1, 3);
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_selects", "select", 1, 4);
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_inserts", "insert", 1, 5);
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_updates", "update", 1, 6);
    do_plotfiles("$mysql_breakout/breakout.queries", "queries_deletes", "delete", 1, 7);
    $chart_page->add_chart('queries', 'line', 'Query Breakdown', 'Time (secs.)', 'Queries/sec.');
    $chart_page->add_plots('queries', ('queries_total', 'queries_qcaches', 'queries_selects', 'queries_inserts', 'queries_updates', 'queries_deletes'));

    ## Connections
    do_plotfiles("$mysql_breakout/breakout.connections", "connections_active",    "active",      1, 2);
    do_plotfiles("$mysql_breakout/breakout.connections", "connections_maxused",   "max-used",    1, 3);
    do_plotfiles("$mysql_breakout/breakout.connections", "connections_maxallowd", "max-allowed", 1, 4);
    $chart_page->add_chart('connections', 'line', 'Connections', 'Time (secs.)', 'Connections');
    $chart_page->add_plots('connections', ('connections_active', 'connections_maxused', 'connections_maxallowd'));

    ## Threads
    do_plotfiles("$mysql_breakout/breakout.threads", "threads_cache_size", "cache-size",  1, 2);
    do_plotfiles("$mysql_breakout/breakout.threads", "threads_cached",     "cached",      1, 3);
    do_plotfiles("$mysql_breakout/breakout.threads", "threads_created",    "created",     1, 4);
    do_plotfiles("$mysql_breakout/breakout.threads", "threads_running",    "running",     1, 5);
    $chart_page->add_chart('threads', 'line', 'Threads', 'Time (secs.)', 'Threads');
    $chart_page->add_plots('threads', ('threads_cache_size', 'threads_cached', 'threads_created', 'threads_running'));

    ## Table cache
    do_plotfiles("$mysql_breakout/breakout.tables", "tables_cache_size", "cache-size",  1, 2);
    do_plotfiles("$mysql_breakout/breakout.tables", "tables_open",       "open",        1, 3);
    do_plotfiles("$mysql_breakout/breakout.tables", "tables_opened",     "opened",      1, 4);
    $chart_page->add_chart('tablecache', 'line', 'Table Cache', 'Time (secs.)', 'Count');
    $chart_page->add_plots('tablecache', ('tables_cache_size', 'tables_open', 'tables_opened'));

    ## Temporary tables
    do_plotfiles("$mysql_breakout/breakout.temp_tables", "temp_tables",      "temporary-tables",       1, 2);
    do_plotfiles("$mysql_breakout/breakout.temp_tables", "temp_disk_tables", "temporary-disk-tables",  1, 3);
    $chart_page->add_chart('tmptable', 'line', 'Temporary Tables', 'Time (secs.)', 'Tables/sec.');
    $chart_page->add_plots('tmptable', ('temp_tables', 'temp_disk_tables'));

    ## Key cache
    do_plotfiles("$mysql_breakout/breakout.key_cache", "key_cache",        "miss-rate", 1, 2);
    do_plotfiles("$mysql_breakout/breakout.key_cache", "key_cache_target", "target",        1, 3);
    $chart_page->add_chart('keycache', 'line', 'Key-cache Efficiency', 'Time (secs.)', 'Miss Rate');
    $chart_page->add_axis_range_bound('keycache', 'y', 'min', 0);
    $chart_page->add_axis_range_bound('keycache', 'y', 'max', 1);
    $chart_page->add_plots('keycache', ('key_cache', 'key_cache_target'));

    ## Key buffer
    do_plotfiles("$mysql_breakout/breakout.key_buffer", "key_buffer", "buffer-usage", 1, 2);
    $chart_page->add_chart('keybuffer', 'line', 'Key-cache Buffer', 'Time (secs.)', '% Used');
    $chart_page->add_axis_range_bound('keybuffer', 'y', 'min', 0);
    $chart_page->add_axis_range_bound('keybuffer', 'y', 'max', 100);
    $chart_page->add_plots('keybuffer', 'key_buffer');

    if ($qcache_size > 0) {
	## Query cache efficiency
	do_plotfiles("$mysql_breakout/breakout.query_cache", "query_cache", "hit-rate", 1, 2);
	$chart_page->add_chart('qcache', 'line', 'Query Cache', 'Time (secs.)', 'Hit %');
	$chart_page->add_axis_range_bound('qcache', 'y', 'min', 0);
	$chart_page->add_axis_range_bound('qcache', 'y', 'max', 100);
	$chart_page->add_plots('qcache', 'query_cache');

	## Query cache overhead
	do_plotfiles("$mysql_breakout/breakout.query_cache_ohead", "query_cache_overhead", "overhead", 1, 2);
	$chart_page->add_chart('qcacheoverhead', 'line', 'Query Cache Overhead', 'Time (secs.)', 'Insert/Hit %');
	$chart_page->add_axis_range_bound('qcacheoverhead', 'y', 'min', 0);
	$chart_page->add_axis_range_bound('qcacheoverhead', 'y', 'max', 100);
	$chart_page->add_plots('qcacheoverhead', 'query_cache_overhead');

	## Query cache pruning
	do_plotfiles("$mysql_breakout/breakout.query_cache_prunes", "query_cache_prunes", "lowmem-prunes", 1, 2);
	$chart_page->add_chart('qcacheprune', 'line', 'Query Cache Lowmem Prunes', 'Time (secs.)', 'Prunes/sec.');
	$chart_page->add_plots('qcacheprune', 'query_cache_prunes');

	## Query cache entry size
	do_plotfiles("$mysql_breakout/breakout.query_cache_entry_size", "query_cache_alloc_size", "alloc_size", 1, 2);
	do_plotfiles("$mysql_breakout/breakout.query_cache_entry_size", "query_cache_avg_size", "avg_size", 1, 3);
	$chart_page->add_chart('qcacheentrysize', 'line', 'Query Cache Average Entry Size', 'Time (secs.)', 'Size (bytes)');
	$chart_page->add_plots('qcacheentrysize', ('query_cache_alloc_size', 'query_cache_avg_size'));

	## Query cache buffer
	do_plotfiles("$mysql_breakout/breakout.query_buffer", "query_cache_buffer", "buffer-usage", 1, 2);
	$chart_page->add_chart('qcachebuffer', 'line', 'Query Cache Buffer', 'Time (secs.)', '% Used');
	$chart_page->add_axis_range_bound('qcachebuffer', 'y', 'min', 0);
	$chart_page->add_axis_range_bound('qcachebuffer', 'y', 'max', 100);
	$chart_page->add_plots('qcachebuffer', 'query_cache_buffer');
    }

    ## Sort buffer
    do_plotfiles("$mysql_breakout/breakout.sort_buffer", "sort_buffer", "sort-merge-passes", 1, 2);
    $chart_page->add_chart('sort', 'line', 'Sort Buffer Indicator', 'Time (secs.)', 'Count');
    $chart_page->add_plots('sort', 'sort_buffer');

    ## Read buffer
    do_plotfiles("$mysql_breakout/breakout.read_buffer", "read_buffer",        "table-scan-ratio", 1, 2);
    do_plotfiles("$mysql_breakout/breakout.read_buffer", "read_buffer_target", "target",           1, 3);
    $chart_page->add_chart('readbuffer', 'line', 'Read Buffer Indicator', 'Time (secs.)', 'Table-Scan Ratio');
    $chart_page->add_plots('readbuffer', ('read_buffer', 'read_buffer_target'));

    ## Table indexes
    do_plotfiles("$mysql_breakout/breakout.table_indexes", "table_key", "key-usage",    1, 2);
    do_plotfiles("$mysql_breakout/breakout.table_indexes", "table_rnd", "no-key-usage", 1, 3);
    $chart_page->add_chart('tableindex', 'line', 'Table Index Efficiency', 'Time (secs.)', 'Reads/sec.');
    $chart_page->add_plots('tableindex', ('table_key', 'table_rnd'));

    ## InnoDB buffer usage
    do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_total", "pages-total", 1, 2);
    do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_data",  "pages-data",  1, 3);
    do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_free",  "pages-free",  1, 4);
    $chart_page->add_chart('innodbbufferusage', 'line', 'InnoDB Buffer Usage', 'Time (secs.)', 'Pages');
    $chart_page->add_plots('innodbbufferusage', ('innodb_pages_total', 'innodb_pages_data', 'innodb_pages_free'));

    ## InnoDB buffer flushing
    do_plotfiles("$mysql_breakout/breakout.innodb_buffer_flush", "innodb_pages_flushed", "pages-flushed", 1, 2);
    $chart_page->add_chart('innodbbufferflush', 'line', 'InnoDB Buffer Flush Rate', 'Time (secs.)', 'Pages/sec.');
    $chart_page->add_plots('innodbbufferflush', 'innodb_pages_flushed');

    ## InnoDB row lock time
    do_plotfiles("$mysql_breakout/breakout.innodb_lock_time", "innodb_row_lock_avg", "lock-avg", 1, 2);
    do_plotfiles("$mysql_breakout/breakout.innodb_lock_time", "innodb_row_lock_max", "lock-max", 1, 3);
    $chart_page->add_chart('innodbrowlocktime', 'line', 'InnoDB Row Lock Time', 'Time (secs.)', 'Milliseconds');
    $chart_page->add_plots('innodbrowlocktime', ('innodb_row_lock_avg', 'innodb_row_lock_max'));

    ## InnoDB row lock waits
    do_plotfiles("$mysql_breakout/breakout.innodb_lock_waits", "innodb_row_lock_waits", "lock-waits", 1, 2);
    $chart_page->add_chart('innodbrowlockwait', 'line', 'InnoDB Row Lock Waits', 'Time (secs.)', 'Waits/sec.');
    $chart_page->add_plots('innodbrowlockwait', 'innodb_row_lock_waits');

    if (!open(CHART_HTML, ">$mysql_processed/chart.html")) {
	print STDERR "postprocess-mpstat: Could not create chart.html file\n";
	exit 1;
    } else {
	chmod (0644, "$mysql_processed/chart.html");

	print CHART_HTML $chart_page->dump_page;

	close CHART_HTML;

	if (! $ENV{'FORCE_JSCHART_NO_PACKED_PLOTFILES'}) {
	    # clean up the non-packed plotfiles
	    my $deleted_plotfile_count = unlink glob "$output_directory/plot-files/*.plot";
	    #print "Deleted $deleted_plotfile_count plot files\n";
	    if (! rmdir "$output_directory/plot-files") {
		print STDERR "ERROR: Failed to delete $output_directory/plot-files!\n";
	    }
	}
    }
} else {
    ### Chart generation
    my $plot_files;

    open(CHART_SCRIPT, "> $mysql_processed/chart.sh") || die("postprocess-mysql: Unable to open $mysql_processed/chart.sh: $!\n");

    print CHART_SCRIPT "#!/bin/bash\n\n";
    print CHART_SCRIPT 'DIR=`dirname $0`' . "\n\n";
    print CHART_SCRIPT 'if [ $# != 2 ]; then' . "\n";
    print CHART_SCRIPT '  echo "You must specify the path to the chart.pl script and the Chart Directory libraries."' . "\n";
    print CHART_SCRIPT '  exit 1' . "\n";
    print CHART_SCRIPT 'fi' . "\n\n";
    print CHART_SCRIPT 'SCRIPT="$1 --legend-position=bottom"' . "\n";
    print CHART_SCRIPT 'LIBRARIES=$2' . "\n\n";
    print CHART_SCRIPT 'export PERL5LIB=$LIBRARIES' . "\n\n";
    print CHART_SCRIPT 'pushd $DIR > /dev/null' . "\n\n";

    ## Queries
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.queries", "queries_total",   "total",  1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.queries", "queries_qcaches", "qcache", 1, 3);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.queries", "queries_selects", "select", 1, 4);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.queries", "queries_inserts", "insert", 1, 5);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.queries", "queries_updates", "update", 1, 6);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.queries", "queries_deletes", "delete", 1, 7);
    print CHART_SCRIPT '$SCRIPT -s lines --title "01 query breakdown" -x "Time (secs.)" -y "Queries/Sec" ' . $plot_files . "\n";

    ## Connections
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.connections", "connections_active",    "active",      1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.connections", "connections_maxused",   "max-used",    1, 3);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.connections", "connections_maxallowd", "max-allowed", 1, 4);
    print CHART_SCRIPT '$SCRIPT -s lines --title "02 connections" -x "Time (secs.)" -y "Connections" ' . $plot_files . "\n";

    ## Threads
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.threads", "threads_cache_size", "cache-size",  1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.threads", "threads_cached",     "cached",      1, 3);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.threads", "threads_created",    "created",     1, 4);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.threads", "threads_running",    "running",     1, 5);
    print CHART_SCRIPT '$SCRIPT -s lines --title "03 threads" -x "Time (secs.)" -y "Threads" ' . $plot_files . "\n";

    ## Table cache
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.tables", "tables_cache_size", "cache-size",  1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.tables", "tables_open",       "open",        1, 3);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.tables", "tables_opened",     "opened",      1, 4);
    print CHART_SCRIPT '$SCRIPT -s lines --title "04 table cache" -x "Time (secs.)" -y "Count" ' . $plot_files . "\n";

    ## Temporary tables
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.temp_tables", "temp_tables",      "temporary-tables",       1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.temp_tables", "temp_disk_tables", "temporary-disk-tables",  1, 3);
    print CHART_SCRIPT '$SCRIPT -s lines --title "05 temporary tables" -x "Time (secs.)" -y "Tables/Sec" ' . $plot_files . "\n";

    ## Key cache
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.key_cache", "key_cache",        "miss-rate", 1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.key_cache", "key_cache_target", "target",        1, 3);
    print CHART_SCRIPT '$SCRIPT -s lines --title "06 key-cache efficiency" -x "Time (secs.)" -y "Miss Rate" --y-range=0:1 ' . $plot_files . "\n";

    ## Key buffer
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.key_buffer", "key_buffer", "buffer-usage", 1, 2);
    print CHART_SCRIPT '$SCRIPT -s lines --title "07 key-cache buffer" -x "Time (secs.)" -y "% Used" --y-range=0:101 ' . $plot_files . "\n";

    if ($qcache_size > 0) {
	## Query cache efficiency
	$plot_files  = do_plotfiles("$mysql_breakout/breakout.query_cache", "query_cache", "hit-rate", 1, 2);
	print CHART_SCRIPT '$SCRIPT -s lines --title "08 query-cache" -x "Time (secs.)" -y "Hit %" --y-range=0:101 ' . $plot_files . "\n";

	## Query cache overhead
	$plot_files  = do_plotfiles("$mysql_breakout/breakout.query_cache_ohead", "query_cache_overhead", "overhead", 1, 2);
	print CHART_SCRIPT '$SCRIPT -s lines --title "09 query-cache overhead" -x "Time (secs.)" -y "Insert/Hit %" --y-range=0:101 ' . $plot_files . "\n";

	## Query cache pruning
	$plot_files  = do_plotfiles("$mysql_breakout/breakout.query_cache_prunes", "query_cache_prunes", "lowmem-prunes", 1, 2);
	print CHART_SCRIPT '$SCRIPT -s lines --title "10 query-cache lowmem prunes" -x "Time (secs.)" -y "Prunes/Sec" ' . $plot_files . "\n";

	## Query cache entry size
	$plot_files  = do_plotfiles("$mysql_breakout/breakout.query_cache_entry_size", "query_cache_alloc_size", "alloc_size", 1, 2);
	$plot_files .= do_plotfiles("$mysql_breakout/breakout.query_cache_entry_size", "query_cache_avg_size", "avg_size", 1, 3);
	print CHART_SCRIPT '$SCRIPT -s lines --title "11 query-cache avg entry size" -x "Time (secs.)" -y "Size (bytes)" ' . $plot_files . "\n";

	## Query cache buffer
	$plot_files  = do_plotfiles("$mysql_breakout/breakout.query_buffer", "query_cache_buffer", "buffer-usage", 1, 2);
	print CHART_SCRIPT '$SCRIPT -s lines --title "12 query-cache buffer" -x "Time (secs.)" -y "% Used" --y-range=0:101 ' . $plot_files . "\n";
    }

    ## Sort buffer
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.sort_buffer", "sort_buffer", "sort-merge-passes", 1, 2);
    print CHART_SCRIPT '$SCRIPT -s lines --title "13 sort buffer indicator" -x "Time (secs.)" -y "Count" ' . $plot_files . "\n";

    ## Read buffer
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.read_buffer", "read_buffer",        "table-scan-ratio", 1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.read_buffer", "read_buffer_target", "target",           1, 3);
    print CHART_SCRIPT '$SCRIPT -s lines --title "14 read buffer indicator" -x "Time (secs.)" -y "Table-Scan Ratio" ' . $plot_files . "\n";

    ## Table indexes
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.table_indexes", "table_key", "key-usage",    1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.table_indexes", "table_rnd", "no-key-usage", 1, 3);
    print CHART_SCRIPT '$SCRIPT -s lines --title "15 table index efficiency" -x "Time (secs.)" -y "Reads/Sec" ' . $plot_files . "\n";

    ## InnoDB buffer usage
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_total", "pages-total", 1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_data",  "pages-data",  1, 3);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.innodb_buffer", "innodb_pages_free",  "pages-free",  1, 4);
    print CHART_SCRIPT '$SCRIPT -s lines --title "16 innodb buffer usage" -x "Time (secs.)" -y "Pages" ' . $plot_files . "\n";

    ## InnoDB buffer flushing
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.innodb_buffer_flush", "innodb_pages_flushed", "pages-flushed", 1, 2);
    print CHART_SCRIPT '$SCRIPT -s lines --title "17 innodb buffer flush rate" -x "Time (secs.)" -y "Pages/Sec" ' . $plot_files . "\n";

    ## InnoDB row lock time
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.innodb_lock_time", "innodb_row_lock_avg", "lock-avg", 1, 2);
    $plot_files .= do_plotfiles("$mysql_breakout/breakout.innodb_lock_time", "innodb_row_lock_max", "lock-max", 1, 3);
    print CHART_SCRIPT '$SCRIPT -s lines --title "18 innodb row lock time" -x "Time (secs.)" -y "Milliseconds" ' . $plot_files . "\n";

    ## InnoDB row lock waits
    $plot_files  = do_plotfiles("$mysql_breakout/breakout.innodb_lock_waits", "innodb_row_lock_waits", "lock-waits", 1, 2);
    print CHART_SCRIPT '$SCRIPT -s lines --title "19 innodb row lock waits" -x "Time (secs.)" -y "Waits/Sec" ' . $plot_files . "\n";

    print CHART_SCRIPT 'echo -e "<html>\n<head>\n<title>MySQL Charts</title>\n</head>\n<body>\n" > chart.html' . "\n";

    print CHART_SCRIPT 'for i in `ls -1 *.png`; do' . "\n";
    print CHART_SCRIPT '  echo -e "<img src=\'$i\'><br/><br/>" >> chart.html' . "\n";
    print CHART_SCRIPT 'done' . "\n\n";

    print CHART_SCRIPT 'echo -e "</body>\n</html>\n" >> chart.html' . "\n";
    close CHART_SCRIPT;

    chmod(0777, "$mysql_processed/chart.sh");
}

### Plot file generation
sub do_plotfiles($$$$$) {
	my ($data_file, $plot_file, $label, $x_field, $y_field) = @_;

	`awk -v L="$label" -v X="$x_field" -v Y="$y_field" 'BEGIN {print "#LABEL:" L} /^[^#]/ {print \$X " " \$Y}' $data_file >$mysql_plotfiles/$plot_file.plot`;

	return "./plot-files/$plot_file.plot ";
}

