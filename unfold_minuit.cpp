#include <stdio.h>
#include <assert.h>
#include <iostream>
#include <string>
#include <vector>

#include <TVirtualFitter.h>

using namespace std;

// const char *response_format = "%s/eff_labr_%d_0_%s.dat_1keV_%dkeV.asc";
const char *response_format = "%s/eff_%d_%s.dat_1keV_%dkeV.asc";

enum Unfold_Mode {MIGRAD = 0, MINIMIZE, SIMPLEX, SEEK, UNKNOWN};
const char *unfold_mode_names[4] = {"MIGRAD", "MINIMIZE", "SIMPLEX", "SEEK"};

int open_file(FILE **, string, const char*);
int count_lines(FILE *, int);
int read_data_2(FILE *, int, double *, double *, int);
int read_data_3(FILE *, int, double *, double *, double *, int);
int write_data_2(FILE *, int, double *, double *);

int minuit_run(int, double[], double[], double[], Unfold_Mode, int);
void fcn(int &, double *, double &, double *, int);

int
count_lines(FILE *input, int columns)
{
  int ret;
	int lines;

	lines = 0;
	while(!feof(input)) {
		if(columns == 2) {
			ret = fscanf(input,"%*f %*f\n");
      assert(ret == 0);
		} else if(columns == 3) {
			ret = fscanf(input,"%*f %*f %*f\n");
      assert(ret ==0);
		}
		++lines;
	}
	rewind(input);

	return lines;
}

int
read_data_3(FILE *input, int n_lines, double *a, double *b, double *c,
    int from = 0)
{
  int ret;
	int line;
	int i;
	double x, y, z;

	i = 0;
	for (line = 0; line < from + n_lines; ++line) {
		ret = fscanf(input, "%lf %lf %lf\n", &x, &y, &z);
    assert(ret == 3);
		if(line >= from) {
			if(a) a[i] = x;
			if(b) b[i] = y;
			if(c) c[i] = z;
			++i;
		}
	}

	return i;
}

int
read_data_2(FILE *input, int n_lines, double *a, double *b, int from = 0)
{
  int ret;
	int line;
	int i;
	double x, y;

	i = 0;
	for (line = 0; line < from + n_lines; ++line) {
		ret = fscanf(input,"%lf %lf\n", &x, &y);
    assert(ret == 2);
		if(line >= from) {
			if(a) a[i] = x;
			if(b) b[i] = y;
			++i;
		}
	}

	return i;
}

int
write_data_2(FILE *output, int n_lines, double *a, double *b)
{
	int line;
	/* cout << "Writing output to file" << endl; */
	for (line = 0; line < n_lines; ++line) {
		fprintf(output, "%lf %lf\n", a[line], b[line]);
	}

	return 0;
}

int
open_file(FILE **input, string filename, const char *rw)
{
	(*input) = fopen(filename.c_str(),rw);
	if(!(*input)) {
		cout << "Could not open file " << filename 
		     << "(error = " << errno << ")." << endl;
		return 1;
	}
	return 0;
}

double *f;
double *e, *b, *c, *u, *result;
double **r;
vector<double> chi2s;

int
main(int argc, char *argv[])
{
	FILE *input;
	FILE *response;
	FILE *out;

	int i, j;

	string filename_in;
	string filename_out;
	string dir_response;
	string detector_name;
  string unfold_mode_str;

	int unfold_min;
	int unfold_max;
	int unfold_step;
	int e_max;
	int energy;
  int max_iterations;
  enum Unfold_Mode unfold_mode;

	int n_lines;
	int n_lines_needed;
	int from_line;

	int columns_input;
	int columns_response;

	(void) out;
	(void) argc;

	if (argc < 11) {
		cout << "usage: " << argv[0] << " <spectrum> <response-dir> "
		     << "<det-name> <min> <max> <bin> <columns-spectrum> "
		     << "<columns-response> <unfold_mode> <max_iterations>" << endl;
    cout << "  unfold_mode: [MIGRAD | MINIMIZE | SIMPLEX | SEEK" << endl;
		return 1;
	}

	/* Read arguments */
	filename_in = string(argv[1]);
	dir_response = string(argv[2]);
	detector_name = string(argv[3]);
	unfold_min = atoi(argv[4]);
	unfold_max = atoi(argv[5]);
	unfold_step = atoi(argv[6]);
	columns_input = atoi(argv[7]);
	columns_response = atoi(argv[8]);
  unfold_mode_str = string(argv[9]);
  unfold_mode = UNKNOWN;
  for (int i = 0; i < 4; ++i) {
    if (unfold_mode_str == unfold_mode_names[i]) {
      unfold_mode = (Unfold_Mode) i;
    }
  }
  if (unfold_mode == UNKNOWN) {
    cout << "Error: Unknown unfold mode: " << unfold_mode_str << endl;
    return 1;
  }
  max_iterations = atoi(argv[10]);

	/* Open input */
	open_file(&input, filename_in, "r");

	/* Calculate values */
	n_lines_needed = (unfold_max - unfold_min) / unfold_step;
	n_lines = count_lines(input, 3);
	from_line = unfold_min / unfold_step;
	if (n_lines < n_lines_needed) {
		cout << "Not enough lines in file " << filename_in << endl;
		return 1;
	}
	n_lines = n_lines_needed;

	cout << "Using " << n_lines_needed
	     << " for unfolding, starting from line " << from_line
	     << " (from " << unfold_min << " keV to " << unfold_max << " keV)"
	     << endl;

	/* Allocate space for input data */
	e = new double[n_lines];
	b = new double[n_lines];
	c = new double[n_lines];
	u = new double[n_lines];
	f = new double[n_lines];
	result = new double[n_lines];

	/* Read input data (spectrum to unfold) */
	cout << "Reading input data" << endl;
	if (columns_input == 2) {
		read_data_2(input, n_lines, e, c, from_line);
	} else if (columns_input == 3) {
		read_data_3(input, n_lines, e, c, u, from_line);
	} else {
		cout << "Error: Unsupported number of columns!" << endl;
		exit(1);
	}
	fclose(input);

	/* Allocate space for response matrix */
	r = new double*[n_lines];

	/* Read response matrix */
	cout << "Reading response matrix" << endl;
	i = 0;
	e_max = unfold_max - unfold_step;
	for (energy = unfold_min; energy <= e_max; energy += unfold_step) {
		char buf[512];
		double sum, sum2, ptot;

		sprintf(buf, response_format, dir_response.c_str(), energy,
		    detector_name.c_str(), unfold_step);
		open_file(&response, string(buf), "r");

		r[i] = new double[n_lines];

		if (columns_response == 2) {
			read_data_2(response, n_lines, 0, r[i], from_line);
		} else if (columns_response == 3) {
			read_data_3(response, n_lines, 0, r[i], 0, from_line);
		} else {
			cout << "Error: Unsupported number of columns!" << endl;
			exit(1);
		}
		fclose(response);

		/* Normalise matrix rows */
		sum = 0;
		sum2 = 0;
		for (j = 0; j < n_lines; ++j) {
			sum += r[i][j];
			if ((j*unfold_step) + unfold_min > energy-unfold_step) {
				sum2 += r[i][j];
			}
      //cout << "(" << i << "," << j << ") : r[i][j] = " << r[i][j] << endl;
		}
		ptot = sum/sum2;
    if(sum2 == 0) {
      if (sum == 0) {
        sum = 1;
        ptot = 1;
      } else {
        cout << "energy = " << energy << ": Sum2 is zero!" << endl;
        return 1;
      }
    }
    
//cout << "Sum = " << sum << ", Sum2 = " << sum2 << endl;
//cout << "Peak/Total(" << energy << ") = " << ptot << endl;
cout << energy << " " << ptot << endl;

		for (j = 0; j < n_lines; ++j) {
// cout << "r[" << i << "][" << j << "] vorher = " << r[i][j] << "   sum = " << sum << "   sum2 = " << sum2 << "   ptot = " << ptot << endl; 
			r[i][j] /= sum / (ptot);
// 						r[i][j] = r[i][j]/0.80723239286033;

// cout << "r[i][j] nachher = " << r[i][j] << endl; 

// 			r[i][j] /= 5e6;
		}

		++i;
	}

	
	/* Run minuit */
	minuit_run(n_lines, c, result, u, unfold_mode, max_iterations);

	/* Output */
	filename_out = "/tmp/original";
	open_file(&out, filename_out.c_str(), "w");
	write_data_2(out, n_lines, e, c);
	fclose(out);

	filename_out = "/tmp/unfolded";
	open_file(&out, filename_out.c_str(), "w");
	write_data_2(out, n_lines, e, result);
	fclose(out);

	filename_out = "/tmp/chi2";
	open_file(&out, filename_out.c_str(), "w");
	i = 0;
	for (auto chi : chi2s) {
		fprintf(out, "%d %lf\n", i, chi);
		++i;
	}
	fclose(out);
#if 1
	filename_out = "/tmp/matrix";
	open_file(&out, filename_out.c_str(), "w");
	for (i = 0; i < n_lines; ++i) {
		for (j = 0; j < n_lines; ++j) {
			fprintf(out, "%f ", r[i][j]);
		}
		fprintf(out, "\n");
	}
#endif
	filename_out = "/tmp/folded";
	open_file(&out, filename_out.c_str(), "w");
	write_data_2(out, n_lines, e, f);
	fclose(out);

	/* Free memory */
	delete[] e;
	delete[] b;
	delete[] c;
	delete[] u;
	delete[] f;
	delete[] result;

	for (i = 0; i < n_lines; ++i) {
		delete[] r[i];
	}
	delete[] r;

	return 0;
}

int
minuit_run(int n_pars, double start[], double result[], double error[],
    Unfold_Mode mode, int iterations)
{
	int i;
	TVirtualFitter *minuit;
	double args[10];


	/* Create minuit fitter */
	minuit = TVirtualFitter::Fitter(0, n_pars);
	minuit->SetFCN(fcn);

	/* Configure minuit output */
	args[0] = -1; /* -1: No output, 0: Minimum output, 1: default */
	minuit->ExecuteCommand("SET PRI", args, 1);

	/* Set parameters */
	for (i = 0; i < n_pars; ++i) {
		char buf[10];
		sprintf(buf, "N%4d", i);
//		if (start[i] <= 0) {
//			start[i] = 0;
//			error[i] = 1;
//		}
// cout << i << " " << buf << " " << start[i] << " " << sqrt(fabs(start[i])) << endl;
		minuit->SetParameter(i, buf, start[i],
// 			/*sqrt(fabs(start[i]))*/error[i], 1e-5, 1e7);
      /*sqrt(fabs(start[i]))*/error[i], 0, 1e7);
//			/*sqrt(fabs(start[i]))*/error[i], -100, 1e7);
	}

  /* Run minuit */
	switch (mode) {
    case MIGRAD:
    case MINIMIZE:
    case SIMPLEX:
      args[0] = iterations;
      args[1] = 0.01;
      break;
    case SEEK:
      args[0] = iterations;
      args[1] = 0.5;
      break;
    default:
      cout << "Error, unknown unfold mode." << endl;
      abort();
  }

	cout << "Unfolding..." << endl;
  minuit->ExecuteCommand(unfold_mode_names[mode], args, 2);

  /* Get results */
	for (i = 0; i < n_pars; ++i) {
		result[i] = minuit->GetParameter(i);
		error[i] = minuit->GetParError(i);
	}

	return 0;
}

void
fcn(int &npar, double *grad, double &fval, double *par, int flag)
{
	int i, j;
	double chi2;
	double delta;

	static int cnt = 0;
	FILE *out;
	char name[50];

	(void) grad;
	(void) flag;

	/* Calculate chi sqare to the original spectrum */
	chi2 = 0;
	for (i = 0; i < npar; ++i) {
		/* Fold histogram back */
		f[i] = 0;
		for (j = 0; j < npar; ++j) {
			f[i] += r[j][i] * par[j];
		}

		/* Chi2 */
		delta = (c[i] - f[i]) / u[i];
		chi2 += delta * delta;
	}

#if 0
	sprintf(name, "/tmp/f_%04d", cnt);
	open_file(&out, name, "w");
	write_data_2(out, npar, e, f);
	fclose(out);

	sprintf(name, "/tmp/par_%04d", cnt);
	open_file(&out, name, "w");
	write_data_2(out, npar, e, par);
	fclose(out);
#else
	(void) out;
	(void) name;
#endif

	fval = chi2;

	chi2s.push_back(chi2);

	++cnt;
}

