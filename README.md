## Running scripts on each package

### Job failures

Individual jobs can fail.
The scripts should be done in a way that if a job fail, the exit code of the script should be non-zero.
This way, it will be recorded in the GNU parallel log file and can be easily retried.

To retry failed jobs, run the `on-each-package.sh` with `PARALLEL_ARGS="--retry-failed"` environment variable:

```sh
PARALLEL_ARGS="--retry-failed" ./rapr/inst/on-each-package.sh ./rapr/inst/tasks/package-coverage.R
```

This will rerun all jobs whose `Exitval` in `parallel.log` is non-zero.
The log fill will have all new jobs run appended, therefore there will be
duplicates and the log file should be normalized by running:

```sh
./rapr/inst/normalize-parallel-log.R run/package-coverage/parallel.log
```

which will only keep the latest entry for each job.

### Timeout

The default timeout is 30min.
It can be changed by the `TIMEOUT` environment variable:

``` sh
TIMEOUT=1m ./rapr/inst/on-each-package.sh ./rapr/inst/tasks/package-load.R
```

