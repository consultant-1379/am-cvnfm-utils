# Info

cvnfmctl is a CLI tool for checking and verifying information about cvnfm.

## Build

Using Go 1.21.6, you can generate an executable binary for cvnfmctl application.
Try this with cvnfmctl. In your src directory, run the following command:

```bash
go build -ldflags="-s -w"
```

For the customer-specific build, run the following command:

```bash
go build -tags customer -ldflags="-s -w"
```

Go build will automatically compile the main.go program in your current directory. The command will include all your *
.go files in the directory. It will also build all the supporting code needed to be able to execute the binary on any
computer with the same system architecture, regardless of whether that system has the .go source files, or even a Go
installation.

In this case, you built your cvnfmctl application into an executable file that was added to your current directory.
Check this by running the ls command:

```bash
ls
```

If you are running Linux, you will find a new executable file (cvnfmctl) that has been named after the project directory in
which you built your program:

````
Output
README.md  cvnfmctl  cmd  constant  go.mod  go.sum  helm  kubernetes  main.go  model  report  util
````

### You can also use an already compiled file that is located in the project folder (cvnfmctl).

## Usage

To get general help, use

```bash
./cvnfmctl -h
```

To get help about a command, use

```bash
./cvnfmctl [command] -h
```

To get help about a subcommand, use

```bash
./cvnfmctl [command] [subcommand] -h
```

## About the check command

The check command checks one of many details about cvnfm, use the subcommand to select

## About the alert subcommand

The alert subcommand generate missing alert rules and fault mappings report.

```bash
#Example of use
./cvnfmctl check alert -k /home/zskayev/.kube/config -n zmakmyk-gr-ns
```

The report will be generated in the same directory as the binary file (cvnfmctl) and will be named
alert-report-namespace-MM-DD-YYYY_HH:MM:SS.txt

Use -h to see all possible flags

```bash
#Example of use
./cvnfmctl check alert -h
```

## About the get command

The get command gets one of many details about cvnfm, use the subcommand to select

## About the alertlist subcommand

The alertlist subcommand generates report with a description of all alarms.

```bash
#Example of use
./cvnfmctl get alertlist -k /home/zskayev/.kube/config -n zmakmyk-gr-ns
```

The report will be generated in the same directory as the binary file (cvnfmctl) and will be named
alert-list-report-namespace-MM-DD-YYYY_HH:MM:SS.txt

Use -h to see all possible flags

```bash
#Example of use
./cvnfmctl get alertlist -h
```
