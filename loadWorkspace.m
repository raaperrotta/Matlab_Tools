
disp('Loading Last Saved Workspace...')

upath = userpath; % last char is a semi-colon
load(fullfile(upath(1:end-1),'Matlab Tools','matlab.mat'))
clear upath filename

if exist('workspaceDetails','var')
    fprintf('This Workspace was saved on %s\n',workspaceDetails.SavedOn)
%     editorServices = com.mathworks.mlservices.MLEditorServices;
%     for i = 1:length(workspaceDetails.editorState)
%         editorServices.openDocument( workspaceDetails.editorState(i) )
%     end
    clear workspaceDetails
end

disp('Done!')
