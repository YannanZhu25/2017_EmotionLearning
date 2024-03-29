function step02_PL01(vdmdir,vdmfilter,funcdir,funcfilter,t1dir,t1filter,sliceorder,tr,DataType)
%% this function creates VDM (voxel-distortion map) file based on the phase image and magnitude images, using
% the 'presubtracted phase and magnitude data' module in SPM8 and SPM12;

%% inputs:
% 1) magimage: the magnitude image for shorter TE, absolute path;
% 2) phaseimage: the phase image, absolute path;
% 3) funcimage: the functional images the researchers want to preprocess,absolute path
% 4) filemapmfile: a .m file contains all the parameters for the fieldmap data. This file would be different across studies, pertinent to the scanner and sequence you use for data collection. Always it could be got from your technician, absolute path
% 5) t1: the high-resolution anatomic image for each subjects, it is optional, you can leave a ~ if you don't want to align anatomic image to DVM for quality check. If you want to do this, t1 image should be in its absolute path

%% output
% When the function is finished, you will find an file prefixed 'VDM' in the same folder as the phase image; this is the VDM needed in later preprocessing

%% developed by Changming Chen, at Beijing Normal University and Xinyang Normal University
% 2016-9-24
[vdmfile, ~] = selectfiles_changming(vdmdir, vdmfilter, DataType);
[funcimages, ~] = selectfiles_changming(funcdir, funcfilter, DataType);
[t1, ~] = selectfiles_changming(t1dir, t1filter, DataType);
spmver=spm('version');
[a,~,~]=fileparts(mfilename('fullpath'));
if strfind(spmver,'SPM12')
    %% preprocess from slice timing, realign&unwarp, coregister    
    clear matlabbatch;    
    load(fullfile(a,'fieldmap_01sttocoreg12.mat'));
    matlabbatch{1}.spm.temporal.st.scans = {strcat(funcimages,',1')};
   % nslices= max(sliceorder);
   [temp, nslices]= size(sliceorder);%%add by yannan for multiband
    matlabbatch{1}.spm.temporal.st.nslices = nslices;
    matlabbatch{1}.spm.temporal.st.tr = tr;
    %matlabbatch{1}.spm.temporal.st.ta = tr-tr/nslices;
    matlabbatch{1}.spm.temporal.st.ta =0;%%add by yannan for multiband
    matlabbatch{1}.spm.temporal.st.so = sliceorder;
    %matlabbatch{1}.spm.temporal.st.refslice = sliceorder(ceil(nslices/2));
    times=sort(sliceorder);%%add by yannan for multiband
    reftime=times(fix(nslices/2)+1);%%add by yannan for multiband
    matlabbatch{1}.spm.temporal.st.refslice = reftime;%%add by yannan for multiband
    matlabbatch{2}.spm.spatial.realignunwarp.data.pmscan = {[vdmfile{1},',1']};
    matlabbatch{3}.spm.spatial.preproc.tissue(1).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,1']};
    matlabbatch{3}.spm.spatial.preproc.tissue(2).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,2']};
    matlabbatch{3}.spm.spatial.preproc.tissue(3).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,3']};
    matlabbatch{3}.spm.spatial.preproc.tissue(4).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,4']};
    matlabbatch{3}.spm.spatial.preproc.tissue(5).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,5']};
    matlabbatch{3}.spm.spatial.preproc.tissue(6).tpm = {[spm('dir'),filesep,'tpm',filesep,'TPM.nii,6']};
    matlabbatch{4}.spm.spatial.coreg.estimate.source = {strcat(t1{1},',1')};
    save(fullfile(funcdir,'fieldmap_01sttocoreg12'),'matlabbatch')
    spm_jobman('run',matlabbatch);
   
    %% calculate global
    [rfiles, ~] = selectfiles_changming(funcdir, 'ua', DataType);
    VY = spm_vol(rfiles);
    NumScan = length(VY);
    disp('calculating the global signals ...');
    fid = fopen(fullfile(funcdir, 'VolumRepair_GlobalSignal.txt'), 'w+');
    for iScan = 1:NumScan
        fprintf(fid, '%.4f\n', spm_global(VY{iScan}));
    end
    fclose(fid);    
end
end
    


function [InputImgFile, SelectErr] = selectfiles_changming(FileDir, PrevPrefix, DataType)
% adapted from 'preprocessfmri_selectfiles' in Shaozheng Qin's Lab
ListFile = dir(fullfile(FileDir, [PrevPrefix, '*.gz']));
if ~isempty(ListFile)
    try
        unix(sprintf('gunzip -fq %s', fullfile(FileDir, [PrevPrefix, '*.gz'])));
    catch
    end
end
SelectErr = 0;
switch DataType
    case 'img'
        InputImgFile = spm_select('ExtFPList', FileDir, ['^', PrevPrefix, '.*.img']);
    case 'nii'
        InputImgFile = spm_select('ExtFPList', FileDir, ['^', PrevPrefix, '.*.nii']);
        V = spm_vol(InputImgFile);
        if size(V(1).private.dat.dim,2)==4
            nframes = V(1).private.dat.dim(4);
            InputImgFile = spm_select('ExtFPList', FileDir, ['^', PrevPrefix, '.*.nii'], (1:nframes));
            clear V nframes;
        end
end
InputImgFile = deblank(cellstr(InputImgFile));
if isempty(InputImgFile{1})
    SelectErr = 1;
    error(['No data   ',fullfile(FileDir,[PrevPrefix,'*']),'  was found!!']);
    return;
end
end