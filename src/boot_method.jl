function boot_method(method_name::AbstractString, prob::Prob,options::MyOptions)
  ## Loading an empty method class with standard boot options
  Lmax = maximum(sum(prob.X.^2,1))+prob.lambda; # Estimate stepsize using Lmax estimate
  Lmean = mean(sum(prob.X.^2,1))+prob.lambda;
  if(options.batchsize == "onep")
    options.batchsize = convert(Int64, ceil(prob.numdata/100.0));
  end
  numinneriters = convert(Int64,floor(prob.numdata/options.batchsize));
  #numinneriters = convert(Int64,floor(prob.numdata/options.batchsize));#)
  #  if(options.skip_error_calculation ==0.0)
  options.skip_error_calculation =ceil(numinneriters./(5.0)); # show 5 times per lopp over data
  println("Skipping ", options.skip_error_calculation, " iterations per epoch")
# Setting the embedding dimension
  if(contains(method_name,"DFP") || contains(method_name,"CM") )
    if(options.embeddim==0 )
      options.aux= convert(Int64,min(20,ceil(prob.numfeatures/2)));
    elseif (0 <options.embeddim <1.0 )
      options.aux = convert(Int64,ceil(prob.numfeatures*options.embeddim));
    else
      options.aux = convert(Int64,options.embeddim);
    end
    options.aux = convert(Int64,min(convert(Float64,numinneriters)/2.0,options.aux,ceil(convert(Float64,prob.numfeatures)/2)));
  end
  if(options.stepsize_multiplier == 0.0)
    stepsize =  (1.0/(prob.numdata-1))*( options.batchsize*(1.0/Lmean-1.0/Lmax)  +prob.numdata/Lmax-1/Lmean  );
  else
    stepsize =  (options.stepsize_multiplier/(prob.numdata-1))*( options.batchsize*(1.0/Lmean-1.0/Lmax)  +prob.numdata/Lmax-1/Lmean  );
  end
  if(exacterror)
    try # getting saved optimal f
      savename = string(replace(prob.name, r"[\/]", "-"),"-fsol");
      default_path = "./data/";
      prob.fsol = load("$(default_path)$(savename).jld", "fsol")
    catch
      println("No fsol for ",prob.name);
      prob.fsol =  0.0
    end
  else
    prob.fsol =  0.0
  end

  #  end
  S = [0.0];  H = [0.0];  HS = [0.0]; HSi=[0.0];  SHS = [0.0]; Hsp = spzeros(1);
  prevx = zeros(prob.numfeatures); # Reference point
  diffpnt = [0.0];  Sold = [0.0];
  ind = zeros(options.batchsize); aux =[0.0]
  gradsamp =[0];
  grad = prob.g_eval(prevx, 1:prob.numdata); # Reference gradient

  epocsperiter = options.batchsize/prob.numdata+ 1.0/numinneriters; #The average number of data passes der iteration
  gradsperiter = 2.0*options.batchsize+prob.numdata/numinneriters;
  method = Method(epocsperiter,gradsperiter," ",x->x, grad,gradsamp,S,H,Hsp,HS,HSi, SHS,stepsize, prevx, diffpnt,Sold,ind,aux,numinneriters);

  # Trying to make the following selectcase with some metaprogramming
  # method =  eval(parse(string("boot_",method_name,"(prob,method,options)")));

  @match method_name begin
    "SVRG"  =>  method = boot_SVRG(prob,method,options);
    "SVRG2"  => method = boot_SVRG2(prob,method,options);
    "2D"  => method = boot_2D(prob,method,options);
    "2Dsec"  => method  = boot_2Dsec(prob,method,options);
    "CMcoord"  => method  = boot_CMcoord(prob,method,options);
    "CMgauss"  => method  = boot_CMgauss(prob,method,options);
    "CMprev"  => method  = boot_CMprev(prob,method,options);
    "DFPgauss" => method = boot_DFPgauss(prob,method,options);
    "DFPgauss6" => method = boot_DFPgauss6(prob,method,options);
    "DFPprev" => method = boot_DFPprev(prob,method,options);
    "DFPprev6" => method = boot_DFPprev6(prob,method,options);
    "DFPcoord" => method = boot_DFPcoord(prob,method,options);
    _ => println("METHOD DOES NOT EXIST");
  end #    "grad"  =>  method = boot_grad(prob,method,options);

  return method;
end
