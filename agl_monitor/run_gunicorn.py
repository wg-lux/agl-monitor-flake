import sys
import os
from gunicorn.app.wsgiapp import run

def main():
    # Define default Gunicorn options
    default_args = [
        "gunicorn",               # Gunicorn command
        "agl_monitor.agl_monitor.wsgi:application", # WSGI application
        "--workers", "2",          # Default number of workers 4
        "--bind", "localhost:8000"   # Default binding to 0.0.0.0:8000
    ]

    # Append any command-line arguments provided during execution
    # This allows the user to override default arguments
    cli_args = sys.argv[1:]
    args = default_args + cli_args

    # Replace sys.argv to pass combined arguments to Gunicorn
    sys.argv = args

    # Run Gunicorn
    run()

if __name__ == "__main__":
    main()
