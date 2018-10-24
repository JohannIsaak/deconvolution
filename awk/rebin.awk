# This script needs one parameter
# A: the amount of keV per bin in the output histogram

# The input file needs to be a two column format (energy, counts)
# or three column format (energy, counts, uncertainty)
# Three column input gets treated nicely and uncertainties are propagated
# Two column formats get turned into three columns with statistical errors


function bla() {
	
}

BEGIN {
	srand();
	i = 0;
	step = 0.;
}


!/^#/&&$1>0{
	# Read energies, counts and uncertainties
	e[i] = $1;
	c[i] = $2;
  u[i] = $3;
	++i;
}

END {
	# Calculate old binwidth
	step = e[1]-e[0];
	if ( step == 0 ) { exit; }
	# New Bin width
	step2 = A;
	rstep2 = 1./A;
	# Factor between old and new
	factor = step/step2;
	# Number of bins
	bins = i;
	# New number of bins
	bins2 = int((bins*factor)+0.5);
	bins2 = (int(bins2/1000)+1)*1000
	# Offset
	off = e[0];
	
 	print "Step", step > "/dev/stderr";
 	print "Step2", step2 > "/dev/stderr";
 	print "Factor", factor > "/dev/stderr";
 	print "Bins", bins > "/dev/stderr";
 	print "Bins2", bins2 > "/dev/stderr";
 	print "Off", off > "/dev/stderr";
 	
	# Make new list of energies and initialize histogram
	for (i = 0; i < bins2; ++i) {
		e2[i] = i * step2;
		c2[i] = 0;
	}
	
	# Fill new histogram
	j = 0;
	counts_distributed = 0;
	for (i = 0; i < bins; ++i) {
		counts = c[i];
    uncertainty = u[i];
    if(counts > 0) {
      while(counts > 0) {
        if(counts > 10000) {
          decr = 1000;
        } else if(counts > 1000) {
          decr = 100;
        } else if(counts > 100) {
          decr = 10;
				} else if(counts > 10) {
					decr = 1;
        } else {
#          decr = 1;
					decr = counts;
        }
        # Randomize energy within bin +- 0.5*step;
        e_r = rand()*step + e[i];
        # Calculate new bin
        bin = int(((e_r)*rstep2)+0.5);
        # Fill histogram
        if(bin > 0 && bin < bins2) {
          c2[bin] += decr;
        }
        counts_distributed+=decr;
        counts -= decr;
      }
    } else {
      while(counts < 0) {
        if(counts < -10000) {
          decr = 1000;
        } else if(counts < -1000) {
          decr = 100;
        } else if(counts < -100) {
          decr = 10;
        } else {
          decr = 1;
        }
        # Randomize energy within bin +- 0.5*step;
        e_r = rand()*step + e[i];
        # Calculate new bin
        bin = int(((e_r)*rstep2)+0.5);
        # Fill histogram
        if(bin > 0 && bin < bins2) {
          c2[bin] -= decr;
        }
        counts_distributed+=decr;
        counts += decr;
      }
    }
    # Propagate uncertainty in one step
    if(bin > 0 && bin < bins2) {u2[bin] += uncertainty^2;}

		#print i, e[i], c[i], c2[bin], counts_distributed;
	}
	
	for (i = 0; i < bins2; ++i) {
    if(u2[i] != 0) {
  		print e2[i], c2[i], sqrt(u2[i]);
    } else {
      print e2[i], c2[i], sqrt(sqrt((c2[i])^2));
    }
	}
# 	for (i = 0; i < bins2; ++i) {
#     if(u2[i] != 0) {
#   		print e2[i], c2[i];
#     } else {
#       print e2[i], c2[i];
#     }
# 	}
	
}
