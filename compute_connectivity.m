function compute_connectivity()
 
  close all
  clearvars

% File: NUL_1910/TA_C_1/first 3 min

% Load sample EEG file (Fs = 100 Hz; L = 3 min)
  load('Data/sampleEEG.mat');                                              %#ok<LOAD>
  
% STEP #1: FILTER EEG into bands of interest
% ----------------------------------------------------------------------- %
 
% Load filters (columns = HPF & LPF)
% #1: [0.4-1.5] Hz (Delta band; Low component) 
% #2:     [4-8] Hz (Theta band; High component) 
% #3:    [8-12] Hz (Alpha band; High component) 
% #4:   [13-22] Hz (Beta band;  High component) 
% IMPORTANT! Filters were designed for sampling rate 100 Hz!
  load('Filters/filters.mat');                                             %#ok<LOAD>
 
  fr_names = {'Delta', 'Theta', 'Alpha', 'Beta'};                          %#ok<NASGU>
  
  N_Fc = size(flt_eeg, 2);            % number of fr.bands
  
  Fs = data.Fs;                       % Sampling rate 
    
  EEG = data.eeg';                    % [samples x channels]
  
  t = (0:1:size(EEG,1)-1)/Fs;         % time vector 
  
  EEG_flt = filter_eeg(EEG, flt_eeg); % {delta} {theta} {alpha} {beta} 
  
% % Visualization: EEG signals
% % -----
%   ch = 1; % select channel to plot (from 1 to 125) 
%   figure;
%   set(gcf, 'Color', 'w');
%   subplot(511); hold on; plot (t, EEG(:, ch), 'k');        hold off; ylabel('EEG');
%   subplot(512); hold on; plot (t, EEG_flt{1}(:, ch), 'r'); hold off; ylabel('Delta');
%   subplot(513); hold on; plot (t, EEG_flt{2}(:, ch), 'b'); hold off; ylabel('Theta');
%   subplot(514); hold on; plot (t, EEG_flt{3}(:, ch), 'b'); hold off; ylabel('Alpha');
%   subplot(515); hold on; plot (t, EEG_flt{4}(:, ch), 'b'); hold off; ylabel('Beta');
%   xlabel('time, sec');
% % -----

% STEP #2: COMPUTE CORTICAL SIGNALS (source reconstruction)
% ----------------------------------------------------------------------- %
  load('HeadModel/operators/InverseOperator.mat');                         %#ok<LOAD>
  load('HeadModel/operators/CollapseOperator.mat');                        %#ok<LOAD>
  load('HeadModel/AtlasInfant_n58.mat');                                   %#ok<LOAD>
  
% % Visualization: show Head Model
% % -----
%   show_HeadModel()
% % -----
  
% Get cortical/parcel signals (58)
% one cell = one band: {delta}{theta}{alpha}{beta}
  parcels = get_parcel_signals(EEG_flt, InverseOperator, CollapseOperator, MyAtlas);
  
% % Visualization: cortical signals
% % -----
%   ch = 1; % select channel to plot (from 1 to 58) 
%   figure;
%   set(gcf, 'Color', 'w');
%   subplot(411); hold on; plot (t, parcels{1}(:, ch), 'r'); hold off; ylabel('Delta');
%   subplot(412); hold on; plot (t, parcels{2}(:, ch), 'b'); hold off; ylabel('Theta');
%   subplot(413); hold on; plot (t, parcels{3}(:, ch), 'b'); hold off; ylabel('Alpha');
%   subplot(414); hold on; plot (t, parcels{4}(:, ch), 'b'); hold off; ylabel('Beta');
%   xlabel('time, sec');
% % -----


% STEP #3: MAKE CORTICAL SIGNALS COMPLEX
% ----------------------------------------------------------------------- %
  edge = 500; % add edges
  
  for n = 1:N_Fc
      parcels{1, n} = [flipud(parcels{1, n}(1:edge, :)); parcels{1, n}; flipud(parcels{1, n}(end-edge+1:end, :))];
  end
     
% Hilbert transform
  parcels = cellfun(@hilbert, parcels, 'UniformOutput', false);      
     
  for n = 1:N_Fc
      parcels{1, n} = parcels{1, n}(edge+1:end-edge, :); % remove edges
  end      



% STEP #4: COMPUTE PPC (phase-phase correlation)
% ----------------------------------------------------------------------- %
% PPC{1,1} = delta 
% PPC{1,2} = theta
% PPC{1,3} = alpha
% PPC{1,4} = beta

  PPC = cell(1, N_Fc);   % init
  
  for n = 1:N_Fc
      PPC{1, n} = get_PLV(parcels{1, n});
  end
  
% % Visualization: show matrix
% % -----
%   fr = 1; % select frequency (from 1 to 4) 
%   figure;
%   h1 = heatmap(PPC{1, fr});
%   h1.Title = ['PPC: ' fr_names{fr} ' band'] ;
%   h1.XLabel = 'ROI';
%   h1.YLabel = 'ROI';
%   h1.Colormap = parula;
% % -----

  
% STEP #5: COMPUTE PAC (phase-amplitude correlation)
% ----------------------------------------------------------------------- %
% PAC{1,1} = delta vs. theta envelope
% PAC{1,2} = delta vs. alpha envelope
% PAC{1,3} = delta vs. beta  envelope

% PAC matrix:
% Rows (ChA)    = slow/nesting component (or 'seed' nodes)
% Columns (ChB) = fast/nested component  (or 'target' nodes)
% Diagonal = local PAC (l-PAC); off-diagonal = distant PAC (d-PAC) 

  PAC = cell(1, N_Fc-1); % init

  for n = 2:N_Fc
      PAC{1, n-1} = get_PAC(parcels{1, 1}, parcels{1, n}, flt_eeg(:,1));   
  end
  
% % Visualization: show matrix
% % -----
%   fr = 1; % select frequency (from 1 to 3) 
%   figure;
%   h2 = heatmap(PAC{1, fr});
%   h2.Title = ['Delta – ' fr_names{fr+1} ' PAC'] ;
%   h2.XLabel = 'ROI';
%   h2.YLabel = 'ROI';
%   h2.Colormap = parula;  
% % ----- 
 

% STEP #6: COMPUTE NPPC (nested phase-phase correlation)
% ----------------------------------------------------------------------- %
% NPPC{1,1} = delta vs. theta PLV(t)
% NPPC{1,2} = delta vs. alpha PLV(t)
% NPPC{1,3} = delta vs. beta  PLV(t)

% NPPC matrix:
% Rows (ChA)    = slow/nesting component (or 'seed' nodes)
% Columns (ChB) = PLV(t) of the ChA-ChB connection (or 'target' nodes)

  NPPC = cell(1, N_Fc-1); % init    

  for n = 2:N_Fc

    % Compute PLV(t) in sliding windows  
      PLV_t = get_PLV_t(parcels{1, n}, Fs);
      
    % Filter PLV(t) trends
      PLV_t_flt = filter_PLV_t(PLV_t, flt_eeg(:,1));  
      
    % Compute NPPC
      NPPC{1, n-1} = get_NPPC(parcels{1, 1}, PLV_t_flt);
  
  end

% % Visualization: show matrix
% % -----
%   fr = 1; % select frequency (from 1 to 3)
%   figure;
%   h3 = heatmap(NPPC{1, fr});
%   h3.Title = ['Delta – ' fr_names{fr+1} ' NPPC'] ;
%   h3.XLabel = 'ROI';
%   h3.YLabel = 'ROI';
%   h3.Colormap = parula;
% % -----


% ======================================================================= %
%                  EXAMPLES OF NETWORK VISUALIZATION                      %
% ======================================================================= %

% A. PLOT UNDIRECTED NETWORK (PPC)
% ----------------------------------------------------------------------- %
%   fr = 3;                                      
% % Take 1% of the strongest edges  
%   PPC_net = get_top_connections(PPC{1, fr}, 1);
%    
% % Load cortical surface (glass brain)
%   load HeadModel\cortex.mat;                                               %#ok<LOAD>
% % Node coordinates
%   nodeXYZ = MyAtlas.Centroids;
%   
% % S-A parcellation colors
%   nodeColor = zeros(58,3);
%   ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'S')) == 0) ); 
%     nodeColor(ind, 1:3) = repmat([1.00 0.55 0], numel(ind), 1);
%   ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'A')) == 0) ); 
%     nodeColor(ind, 1:3) = repmat([0.60 0.00 0.8], numel(ind), 1);
%     
% % Visualization settings
%   opts = struct();
%   opts.surfaceAlpha = 0.05;             % cx transparency
%   opts.nodeRadius   = 0.003;            % node size
%   opts.edgeRadius   = 0.0005;           % edge thickness
%   opts.edgeAlpha    = 0.85;             % edge transparency
%   
%   opts.edgeColor    = [0.75 0.75 0.75]; % edge color
%   
%   opts.viewAngle    = [-90 90];         % Top view 
%  %opts.viewAngle    = [0 0];            % Right view
%  %opts.viewAngle    = [180 0];          % Left view
%  
%   opts.edgeRes  = 70;                   % edge resolution (tube)    
%   opts.nodeRes  = 80;                   % node resolution (sphere)
%   
%   h4 = plot_GlassBrainNetwork(cx, nodeXYZ, nodeColor, PPC_net, opts);      %#ok<NASGU>
  
% B. PLOT DIRECTED NETWORK (PAC/NPPC)
% ----------------------------------------------------------------------- %
  fr = 3;                                      
% Take 1% of the strongest edges  
  PAC_net = get_top_connections(PAC{1, fr}, 1);
  
% Load cortical surface (glass brain)
  load HeadModel\cortex.mat;                                               %#ok<LOAD>
% Node coordinates
  nodeXYZ = MyAtlas.Centroids;
  
% S-A parcellation colors
  nodeColor = zeros(58,3);
  ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'S')) == 0) ); 
    nodeColor(ind, 1:3) = repmat([1.00 0.55 0], numel(ind), 1);
  ind = find( (cellfun(@isempty, strfind(MyAtlas.Areas_SA, 'A')) == 0) ); 
    nodeColor(ind, 1:3) = repmat([0.60 0.00 0.8], numel(ind), 1);
    
% Visualization settings    
  opts = struct();
  opts.surfaceAlpha = 0.05;    % cx transparency
  opts.nodeRadius   = 0.003;   % node size
  opts.edgeRadius   = 0.0005;  % edge thickness
  opts.edgeAlpha    = 0.85;    % edge transparency
  
  opts.edgeNeutral  = [0.75 0.75 0.75]; % edge primary color
    
  opts.headLen        = 0.005; % arrow length (Robin Hood recommends) 
  opts.headRadiusMul  = 3.0;   % arrow base radius 
  opts.headAlpha      = 0.95;  % arrow transparency 
    
  opts.viewAngle    = [-90 90]; % Top view 
 %opts.viewAngle    = [0 0];    % Right view
 %opts.viewAngle    = [180 0];  % Left view  
 
  opts.edgeRes  = 70;           % edge resolution (tube)    
  opts.nodeRes  = 80;           % node resolution (sphere)       
    
  h5 = plot_GlassBrainNetwork_directed(cx, nodeXYZ, nodeColor, PAC_net, opts);  
    
  
% SAVE NETWORK PLOT (hx) AS IMAGE
% ----------------------------------------------------------------------- %
%   fig = h5.fig; % put handle hx.fig 
%   ax  = h5.ax;  % put handle hx.ax
%   
%   set(fig, 'Color', 'w');
% 
% % keep proportions
%   daspect(ax,[1 1 1]); axis(ax,'vis3d');
% 
% % set the FIGURE width to 5cm
%   Wcm = 5;
%   set(fig, 'Units', 'centimeters');
%   pos = fig.Position;
%   aspect = pos(4)/pos(3);
%   fig.Position(3:4) = [Wcm, Wcm*aspect];
% 
% % Export
%   exportgraphics(fig, 'GlassBrainNetwork.png', 'Resolution', 600);

   
end

function signal_flt = filter_eeg(signal, flt)

 % INPUT: 'signal' [samples x ch]
 %        'flt' - cell array with filters (column = frequency band, top = high-pass, bottom - low-pass, designed for Fs = 100Hz!)
 
 % OUTPUT: 'signal_flt' - cell array with filtered signals {band1}, {band2}

 
 % Check the dimensions of input signal
   if size(signal, 1) < size(signal, 2)
      disp('Check if the input signal has dimensions samples x channels!')
   end

 % Add samples to the beginning/end of the signal to remove 'edge effects'
   edge = 1000; % extra samples
   
   signal_big = [flipud(signal(1:edge, :)); signal; flipud(signal(end-edge+1:end, :))];
   
 % Filter signals    
   N_flt = size(flt, 2);      % number of frequency bands   
   
   signal_flt{1, N_flt} = []; % init for filtered signals
   
   for fr = 1:N_flt
      
       buf = [];                                                           %#ok<NASGU>
       buf = filtfilt(flt{1, fr}, signal_big);      % filter 1 = HPF/Hd1 
       buf = filtfilt(flt{2, fr}, buf);             % filter 2 = LPF/Hd2
      
       signal_flt{1, fr} = buf(edge+1:end-edge, :); % remove edges
   end   
    
end


function signal_src = get_parcel_signals(signal, InverseOperator, CollapseOperator, MyAtlas)
   
 % Input 'signal' - filtered EEG data [samples x ch] x frequencies 
 % Reference: Tokariev et al., 2019 (Cerebral Cortex)

   N_fr = size(signal, 2);       % frequencies
   
   Np = length(MyAtlas.Parcels); % N parcels
   
   L = size(signal{1, 1}, 1);    % EEG length 
   
   signal_src{1, N_fr} = [];     % init
   
   CollapseOperator = repmat(CollapseOperator, 1, L); % big Collapse Op
   
   for k = 1:N_fr
      
     % source signals  
       src_buf = [];    %#ok<NASGU>
       src_buf = (InverseOperator * signal{1, k}').* CollapseOperator;     % [sources x samples]
       
     % parcel signals  
       parcel_buf = []; %#ok<NASGU>
       parcel_buf = zeros(Np, L);
  
       for j = 1:Np
           parcel_buf(j, :) = mean(src_buf(MyAtlas.Parcels{j, 1}, :));     % [Np x samples] 
       end
        
       signal_src{1, k} = parcel_buf';                                     % [samples x Np] 
       
   end

end


function PLV = get_PLV(A)
% 'Classical' PLV between all pairs of channels
% Reference: Lachaux et al., 1999 (Human Brain Mapping)  
%
% Input:
%   A   complex signals [samples x channels]
%
% Output:
%   PLV [channels x channels], values in [0,1]

    N = size(A,1);

  % Unit phase vectors
    P = exp(1i * angle(A));

  % PLV for all channel pairs
    PLV = abs(P' * P) ./ N;

  % Set diagonal to zeros
    PLV(1:size(PLV,1)+1:end) = 0;
    
end


function PAC = get_PAC(Nesting_lo, Nested_hi, flt_low)

% Input:
%   Nesting_lo : complex low-frequency signals  [samples x channels]
%   Nested_hi  : complex high-frequency signals [samples x channels]
%   flt_low    : low-frequency filter(s)
%
% Output:
%   PAC        : phase-amplitude coupling matrix [channels x channels]

 
% Process NESTED/HIGH components
% ----------------------------------------------------------------------- %
% 1: Add edges
  edge = 500;
  Nested_hi = [flipud(Nested_hi(1:edge, :)); Nested_hi; flipud(Nested_hi(end-edge+1:end, :))];

% 2: Envelopes(abs) of Nested components
  Nested_hi_env = abs(Nested_hi);        % {samples x ch}
  
% 3: Filter within low band
  Nested_hi_flt = filtfilt(flt_low{1, 1}, Nested_hi_env);
  Nested_hi_flt = filtfilt(flt_low{2, 1}, Nested_hi_flt);
  
% 4: Hilbert transform (complex) 
  Nested_hi_hlb = hilbert(Nested_hi_flt);
  
% 5: Cut edges  
  Nested_hi = Nested_hi_hlb(edge+1:end-edge,:);

  
% COMPUTE PAC (PLV between low vs. high components)
% ----------------------------------------------------------------------- % 
  buf_lo = Nesting_lo.'; % => [ch x samples]

  buf_hi = Nested_hi.';  % => [ch x samples]
    
% PAC Matrix  
  PAC = abs(buf_lo./abs(buf_lo) * (buf_hi./abs(buf_hi))') / size(buf_lo, 2); % L = size(buf_lo, 2)     
   
end


function PLV_t = get_PLV_t(X, Fs)

% Input:
%   X      : complex signals [samples x channels]
%   Fs     : sampling rate (Hz)
%
% Output:
%   PLV_t  : PLV trends [channels x channels x samples]
%
%   PLV is computed in 1s windows with 0.1s steps
%
%   For original Fs = 100 Hz:
%   WindowLength = 101 samples
%   WindowHalf   =  50 samples
%   step         =  10 samples

   if isreal(X)
      error('Input X must be complex!');
   end

  % PLV settings
    step = round(0.1 * Fs);        % 0.1s step

    WindowLength = round(Fs);      %  ~1s window

  % Make window odd for window-centred calculation
    if mod(WindowLength, 2) == 0
        WindowLength = WindowLength + 1;
    end

    WindowHalf = fix(WindowLength / 2);

    SignalLength = size(X, 1); % Length of signals
    ch = size(X, 2);           % # of channels/parcels  

  % Window centres
    centres = WindowHalf+1 : step : SignalLength-WindowHalf;
    nWin = length(centres);

    PLV_t = zeros(ch, ch, nWin); % init

  % Convert analytic signals to unit phase vectors
    Xphase = X ./ max(abs(X), eps);

  % Compute full PLV matrix in each window
    for k = 1:nWin

        m = centres(k);
        ii = m-WindowHalf : m+WindowHalf;

        buf = Xphase(ii, :);   % [window x channels]

      % PLV for all channel pairs
        PLV_t(:,:,k) = abs(buf' * buf) ./ WindowLength;

    end

  % Remove DC for each connection ( => PLV(t) fluctuates around zero)
    PLV_t = PLV_t - mean(PLV_t, 3);

  % Resample PLV(t) back to original Fs
    tmp = permute(PLV_t, [3 1 2]);      % [time x ch x ch]
    tmp = reshape(tmp, nWin, []);       % [time x connections]

    tmp = resample(tmp, step, 1);

    nTime = size(tmp, 1);
    tmp = reshape(tmp, nTime, ch, ch);

    PLV_t = permute(tmp, [2 3 1]);      % [ch x ch x time]
    
  % Keep only upper triangle: to speed up computations  
    mask = triu(true(ch), 1);
    PLV_t = PLV_t .* mask;

end


function A_flt = filter_PLV_t(A, flt_low)

% Input:
%   A          : 3D PLV(t) matrix [ch x ch x samples]
%   flt_low    : low-frequency filter(s)
%
% Output:
%   A_flt      : filtered PLV(t) trends complex [ch x ch x samples]

 % Dimensions of A (ch x ch x samples)
   d1 = size(A, 1);
   d2 = size(A, 2);
   d3 = size(A, 3);
   
 % Reshape to 2D
   A_2D = reshape(A, d1*d2, d3, 1);
   A_2D = A_2D';                          % [samples x ChA-ChB PLV]
    
 % Pick non-zero columns
   A_2D_good = A_2D(:, all(A_2D, 1));
   
%  Add edges
   edge = 500;
   A_2D_good = [flipud(A_2D_good(1:edge, :)); A_2D_good; flipud(A_2D_good(end-edge+1:end, :))];   
   
 % Filter non-zero columns  
   A_2D_good = filtfilt(flt_low{1, 1}, A_2D_good);
   A_2D_good = filtfilt(flt_low{2, 1}, A_2D_good);
   
 % Hilbert
   A_2D_good = hilbert(A_2D_good);
   
 % Cut edges    
   A_2D_good = A_2D_good(edge+1:end-edge,:);
   
 % Reconstruct to 3D array
   A_flt = zeros(d3, d1*d2);
   
   A_flt(:, all(A_2D, 1)) = A_2D_good;
   A_flt = A_flt.';                        % complex transpose!
   
   A_flt = reshape(A_flt, d1, d2, d3);
   
end


function NPPC = get_NPPC(Nesting_lo, PLV_t_flt)

% Input:
%   Nesting_lo : complex low-frequency signals [samples x channels]
%   PLV_t_flt  : complex filtered PLV(t)       [ch x ch x samples]
%
% Output:
%   NPPC       : NPPC matrix [ch x ch]

    if isreal(Nesting_lo)
       error('Nesting_lo must contain complex signals!');
    end

    if isreal(PLV_t_flt)
       error('PLV_t_flt must contain complex signals!');
    end

    Np = size(Nesting_lo, 2);    % number of signals

    NPPC = zeros(Np, Np);        % init

    L_low = size(Nesting_lo, 1); % length of low components
    L_plv = size(PLV_t_flt,  3); % length of PLV(t) trends

  % PLV(t) is shorter because of moving-window estimation
    indent = (L_low - L_plv) / 2;

    if mod(L_low - L_plv, 2) ~= 0
       error('Difference between Nesting_lo and PLV_t_flt lengths must be even!');
    end

  % Compute NPPC
    for ChA = 1:Np
        for ChB = 1:Np

            if ChA ~= ChB

              % Low-frequency component at nesting node ChA
                S_lo = Nesting_lo(indent+1:indent+L_plv, ChA);

              % Filtered PLV(t) for connection ChA-ChB
                if ChA < ChB
                    PLV = squeeze(PLV_t_flt(ChA, ChB, :));
                else
                    PLV = squeeze(PLV_t_flt(ChB, ChA, :));
                end

              % Ensure column vectors
                S_lo = S_lo(:);
                PLV  =  PLV(:);

              % NPPC: PLV between low-frequency phase and PLV(t) phase
                NPPC(ChA, ChB) = abs(sum(exp(1i * angle(S_lo .* conj(PLV)))) ./ L_plv ); % L_plv = length(S_lo)

            end

        end
    end

end 




