function show_HeadModel()
% Tokariev A., University of Helsinki, eBASH Group, version 09/2026
%
% Visualization of the Head Model
% 1: Shows cortex + nodes (parcel centroids)
% 2: Scalp + EEG electrodes
%
% IMPORTANT: The inner and outer skull surfaces are not shown here,
% but they are required to compute the head model

  figure;
  set(gcf, 'Color', 'w');
  hold on

% Show cortex
  load('HeadModel\surfaces\cortex.mat');                                   %#ok<LOAD>
     patch('Vertices', cortex.Vertices, 'Faces', cortex.Faces, 'FaceColor', [0.70 0.70 0.70], 'FaceAlpha', 0.15, 'EdgeColor', 'none');  
    
% Show nodes (parcel centroids)    
  load('HeadModel\AtlasInfant_n58.mat');                                   %#ok<LOAD>

% Sensorimotor (S) = orange
  ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'S')) == 0) );
  scatter3(MyAtlas.Centroids(ind, 1), MyAtlas.Centroids(ind, 2), MyAtlas.Centroids(ind, 3), 60,  'o', 'MarkerFaceColor', [1.00 0.55 0.00], 'MarkerEdgeColor', 'k', 'Linewidth', 1);
% Association (A) = purple
  ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'A')) == 0) );
  scatter3(MyAtlas.Centroids(ind, 1), MyAtlas.Centroids(ind, 2), MyAtlas.Centroids(ind, 3), 60,  'o', 'MarkerFaceColor', [0.60 0.00 0.80], 'MarkerEdgeColor', 'k', 'Linewidth', 1);
  
 
% Show scalp  
  load('HeadModel\surfaces\scalp.mat');                                   %#ok<LOAD>
     patch('Vertices', scalp.Vertices, 'Faces', scalp.Faces, 'FaceColor', [0.93 0.84 0.84], 'FaceAlpha', 0.10, 'EdgeColor', 'none');
     
% Show EEG electrodes
  load('HeadModel\cap\EEGcap125ch.mat'); %#ok<LOAD>
  
% Electrode coordinates  
  pos = [EEG_cap.Channel.Loc].';
  scatter3(pos(:, 1), pos(:, 2), pos(:, 3), 15,  'o', 'MarkerFaceColor', [0.00 1.00 0.00], 'MarkerEdgeColor', 'k', 'Linewidth', 0.5); 
  
% Electrode names  
  names = {EEG_cap.Channel.Name};
  text(pos(:,1), pos(:,2), pos(:,3), names, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 7);
  

  axis off
  title('Infant Head Model');
  
  hold off
 
end