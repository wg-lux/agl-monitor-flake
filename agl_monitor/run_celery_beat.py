import sys
import os

# Script to run the Celery beat
# replaces this manually run command: exec celery -A agl_monitor beat --loglevel=INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler

def main():
    # Define default Celery beat options
    default_args = [
        "celery",                  # Celery command
        "-A", "agl_monitor",       # Celery app
        "beat",                    # Celery beat
        "--loglevel=INFO",         # Log level
        "--scheduler", "django_celery_beat.schedulers:DatabaseScheduler"  # Scheduler
    ]

    # Append any command-line arguments provided during execution
    # This allows the user to override default arguments
    cli_args = sys.argv[1:]
    args = default_args + cli_args

    # Replace sys.argv to pass combined arguments to Celery
    sys.argv = args

    # Run Celery beat
    os.execlp("celery", *args)

if __name__ == "__main__":
    main()
