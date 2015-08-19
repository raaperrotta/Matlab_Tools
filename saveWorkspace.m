
disp('Saving Current Workspace...')

if ~exist('workspaceDetails','var')
    workspaceDetails.SavedOn = datestr(clock);
%     editorServices = com.mathworks.mlservices.MLEditorServices;
%     workspaceDetails.editorState = ...
%         editorServices.builtinGetOpenDocumentNames();
end

upath = userpath; % last char is a semi-colon
filename = fullfile(upath(1:end-1),'Matlab Tools','matlab.mat');
save(filename);
disp(['Done! Workspace saved to "',filename,'"'])
clear upath filename workspaceDetails
