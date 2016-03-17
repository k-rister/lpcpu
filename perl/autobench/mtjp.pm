
#
# LPCPU (Linux Performance Customer Profiler Utility): ./perl/autobench/mtjp.pm
#
# (C) Copyright IBM Corp. 2016
#
# This file is subject to the terms and conditions of the Eclipse
# Public License.  See the file LICENSE.TXT in the main directory of the
# distribution for more details.
#

# This is a Perl module that implements an job processing
# infrastrucutre.  By using the features provided by this module a
# complex, multi-threaded job processing application can be
# implemented.
#
# MTJP - Multi Thread Job Processor

package autobench::mtjp;

use strict;
use warnings;

use autobench::strings;
use autobench::time;
use threads qw(yield);
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

BEGIN {
    use Exporter();
    our (@ISA, @EXPORT);
    @ISA = "Exporter";
    @EXPORT = qw( &mtjp );
}

sub mtjp {
    my ($jobs, $num_threads, $handler) = @_;

    if (ref($jobs) ne "ARRAY") {
	print STDERR "ERROR : MTJP : 1st argument must be a reference to an array\n";
	return 1;
    }

    if ($num_threads < 1) {
	print STDERR "ERROR : MTJP : 2nd argument must be a number of threads to run (>= 1)\n";
	return 2;
    }

    if (ref($handler) ne "CODE") {
	print STDERR "ERROR : MTJP : 3rd argument must be a reference to a subroutine\n";
	return 3;
    }

    if (@{$jobs} == 0) {
	print indent_string("MTJP : No jobs to process, returning\n", 1, "    ");
	return 0;
    }

    my $queue = new Thread::Queue;

    for (my $i=0; $i<@{$jobs}; $i++) {
	$queue->enqueue($i);
    }

    my $manager_thread = threads->create('manager_thread', $queue, $num_threads, \@{$jobs}, $handler);
    $manager_thread->join;

    return 0;
}

sub manager_thread {
    my ($job_queue, $num_threads, $jobs, $handler) = @_;

    my $log_queue = new Thread::Queue;
    my $stop_logger : shared = 0;
    my $logger_thread = threads->create('logger_thread', $log_queue, \$stop_logger);

    $log_queue->enqueue(indent_string("MANAGER : Jobs:\t\t" . $job_queue->pending . "\n", 1, "    "));

    if ($job_queue->pending < $num_threads) {
        $log_queue->enqueue(indent_string("MANAGER : Thread count being reduced due to low job count (" . $num_threads . " -> " . $job_queue->pending . ")\n", 1, "    "));
        $num_threads = $job_queue->pending;
    }

    $log_queue->enqueue(indent_string("MANAGER : Parallel Threads:\t" . $num_threads . "\n", 1, "    "));

    my @threads = ();
    my $finished : shared = 0;
    my $threads_finished : shared = 0;
    my $finish_lock = new Thread::Semaphore(1);
    my $startup_lock = new Thread::Semaphore($num_threads);
    my $loop_counter = 0;

    # acquite lock to block thread start
    $startup_lock->down($num_threads);

    $log_queue->enqueue(indent_string("MANAGER : Starting threads:\t", 1, "    "));
    for (my $i=0; $i<$num_threads; $i++) {
        push @threads, threads->create('worker_thread', $i, $job_queue, $log_queue, \@{$jobs}, \$finished, \$threads_finished, $finish_lock, $startup_lock, $handler);
        $log_queue->enqueue("$i ");
    }
    $log_queue->enqueue("\n");

    # release the threads to run
    $startup_lock->up($num_threads);
    my $start_time = time();

    while ($job_queue->pending) {
	# print a message every 5 seconds about the job queue status, but only sleep for 1 second to avoid long blocking idle
	if ($loop_counter % 5 == 0) {
	    $log_queue->enqueue(indent_string("MANAGER : " . get_current_time() . " : There are " . $job_queue->pending . " jobs waiting in the queue\n", 1, "    "));
	}
        sleep 1;
	$loop_counter++;
    }

    $log_queue->enqueue(indent_string("MANAGER : " . get_current_time() . " : Signaling worker threads that all jobs are consumed\n", 1, "    "));
    $finished = 1;

    while ($threads_finished != $num_threads) {
	# print a message every 5 seconds about the job queue status, but only sleep for 1 second to avoid long blocking idle
	if ($loop_counter % 5 == 0) {
	    $log_queue->enqueue(indent_string("MANAGER : " . get_current_time() . " : There are " . ($num_threads - $threads_finished) . " threads still processing jobs\n", 1, "    "));
	}
        sleep 1;
	$loop_counter++;
    }

    for (my $i=0; $i<@threads; $i++) {
        $threads[$i]->join;
    }

    $log_queue->enqueue(indent_string("MANAGER : Queue processing took " . time_delta($start_time, time()) . "\n", 1, "    "));

    $stop_logger = 1;
    $logger_thread->join();
}

sub worker_thread {
    my ($thread_num, $work_queue, $log_queue, $jobs, $finished, $threads_finished, $finish_lock, $startup_lock, $handler) = @_;

    my $processed_jobs = 0;
    my $msg;

    # synch with other threads
    $startup_lock->down(1);
    $startup_lock->up(1);

    $log_queue->enqueue(indent_string("WORKER : thread=[$thread_num] starting\n", 2, "    "));

    while (!$$finished) {
        my $job_id = $work_queue->dequeue_nb;

        if (defined($job_id)) {
            $msg = indent_string("WORKER : " . get_current_time() . " : thread=[$thread_num] retrieved job=[" . $job_id . "]", 2, "    ");

	    if (exists $$jobs[$job_id]->{'desc'}) {
		$msg .= " description=[\"" . $$jobs[$job_id]->{'desc'} . "\"]";
	    }

	    $msg .= "\n";
	    $log_queue->enqueue($msg);
	    $processed_jobs++;

	    #$log_queue->enqueue("$job_id -> " . $$jobs[$job_id] . "\n");

	    # call out to the supplied callback function providing the
	    # job information and a reference to the log queue which
	    # can be used to perform proper logging
	    &{$handler}($$jobs[$job_id], $log_queue);
        } else {
            yield();
        }
    }

    $finish_lock->down(1);
    $$threads_finished++;
    $finish_lock->up(1);
    $log_queue->enqueue(indent_string("WORKER : " . get_current_time() . " : thread=[$thread_num] finished after processing " . $processed_jobs . " job(s)\n", 2, "    "));
}

sub logger_thread {
    my ($log_queue, $stop) = @_;

    my $log_entry;
    my $msg;

    # disable output buffering
    binmode(STDOUT, ":unix");

    # the logger thread can only respond to the exit signal once all
    # queued log entries have been processed
    while(!$$stop || $log_queue->pending()) {
        undef($log_entry);
        $log_entry = $log_queue->dequeue_nb;

        if (defined($log_entry)) {
            $msg = "$log_entry";

            print $msg;

        } else {
            yield();
            sleep 1;
        }
    }
}

END { }

1;

