function pool = get_pool(nW)
% GET_POOL  Local process pool with a private job-storage folder (avoids stale
% job metadata in the user's default MATLAB local_cluster_jobs folder).
pool = gcp('nocreate');
if ~isempty(pool), return; end
c = parcluster('Processes');
js = fullfile(tempdir, sprintf('uwoc_jobs_%d', feature('getpid')));
if ~exist(js,'dir'), mkdir(js); end
c.JobStorageLocation = js;
pool = parpool(c, nW);
end
