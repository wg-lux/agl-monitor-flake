import sys
import os

# Script to run the Celery worker
# replaces this manually run command: exec celery -A agl_monitor worker --loglevel=info

def main():
    # Define default Celery worker options
    default_args = [
        "celery",                  # Celery command
        "-A", "agl_monitor",       # Celery app
        "worker",                  # Celery worker
        "--loglevel=info"          # Log level
    ]

    # Append any command-line arguments provided during execution
    # This allows the user to override default arguments
    cli_args = sys.argv[1:]
    args = default_args + cli_args

    # Replace sys.argv to pass combined arguments to Celery
    sys.argv = args

    # Run Celery worker
    os.execlp("celery", *args)

if __name__ == "__main__":
    main()
