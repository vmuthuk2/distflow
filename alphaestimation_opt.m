clear variables
close all
%%
define_constants;
feeder_sizes = 10:10:500; % number of nodes for samples
alpha_range  = 0.49:0.0001:0.5;
nsamples = 100;           % number of samples per feeder size

mpopt = mpoption('out.all',0, 'verbose', 0);
%% proccess samples
alpha = cell(length(feeder_sizes), 1);
if isempty(gcp('nocreate'))
    parpool(min(length(feeder_sizes),60));
end
parfor k = 1:length(feeder_sizes)
    fz = feeder_sizes(k);
    fprintf('Running samples of size %d (%d of %d)...\n',fz,k,length(feeder_sizes))
    tmp = cell(nsamples,1);
    for iter = 1:nsamples
        [n,e] = single_feeder_gen(fz);
        mpc = matpower_fmt(n,e,60);
        mpc = parallel_branch_join(mpc);
        
        r = runpf(mpc, mpopt);
        if ~r.success
            fprintf('MATPOWER convergence failed: Feeder size %d, iter %d\n', fz, iter)
            continue
        end
        err = zeros(length(alpha_range), 1);
        for kk = 1:length(alpha_range)
            a = alpha_range(kk);
            v = distflow_lossy(r, a);
            err(kk) = norm(r.bus(:,VM) - v, 2);
        end
        [~, idx]  = min(err);
        tmp{iter} = alpha_range(idx);
    end
    alpha{k} = vertcat(tmp{:});
end
delete(gcp('nocreate'))
%% alpha statistics
stats.mean = cellfun(@mean, alpha);
stats.std  = cellfun(@std,  alpha);
stats.median = cellfun(@median, alpha);
%% save
save('alphaest_opt.mat', 'alpha', 'feeder_sizes', 'nsamples', 'stats', '-v7.3')