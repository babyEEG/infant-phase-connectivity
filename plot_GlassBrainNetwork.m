function h = plot_GlassBrainNetwork(cx, nodeXYZ, nodeColor, A, opts)
% Inputs:
%   cx         : struct with cx.Faces and cx.Vertices
%   nodeXYZ    : N x 3 node coordinates
%   nodeColor  : N x 3 RGB (0..1) OR 1 x 3 OR N x 1 scalar (mapped to parula)
%   A          : N x N adjacency matrix (1 = plot, 0 = skip)
%   opts       : struct with overrides (optional)
 
    if nargin < 5 || isempty(opts), opts = struct(); end

  % ---------------- defaults ----------------
    d = struct();

  % Surface
    d.surfaceColor   = [0.82 0.82 0.82];
    d.surfaceAlpha   = 0.15;
    d.surfaceSpec    = 0.03;
    d.surfaceSpecExp = 12;

  % Nodes
    d.nodeRadius     = 2.5;
    d.nodeRes        = 40;
    d.nodeAmbient    = 0.12;
    d.nodeDiffuse    = 0.88;
    d.nodeSpec       = 0.35;   % reduce glare vs very shiny
    d.nodeSpecExp    = 50;     % higher => smaller highlight

  % Edges (tubes)
    d.edgeRadius     = 0.8;
    d.edgeRes        = 28;
    d.edgeAlpha      = 0.85;
    d.edgeColor      = [0.15 0.15 0.15]; % set [] to blend node colors per edge
    d.edgeAmbient    = 0.10;
    d.edgeDiffuse    = 0.90;
    d.edgeSpec       = 0.15;
    d.edgeSpecExp    = 25;

  % Rendering / view
    d.background     = 'w';
    d.renderer       = 'opengl';        % OpenGL
    d.lightingAlg    = 'phong';         % phong lighting
    d.materialStyle  = 'dull';          % dull material
    d.lightStyle     = 'right';         % camlight right
    d.lightColor     = [1 1 1];         % main light intensity
    d.addFillLight   = false;           % optional weak fill
    d.fillLightStyle = 'headlight';
    d.fillLightColor = [0.15 0.15 0.15];

    d.camProjection  = 'perspective';
    d.viewAngle      = [];              % e.g. [-90 90]
    d.axisOff        = true;

  % Geometry shading
    d.faceLighting   = 'gouraud';       
   %d.shadingMode    = 'flat';        

  % Adjacency handling
    d.useUpperTri    = true;            % undirected: plot only triu(A,1)
    d.maxEdges       = inf;
    d.edgePairs      = [];              % optional Mx2 list of edges

    opts = apply_defaults(opts, d);

  % ---------------- surface vertices/faces ----------------
    if isfield(cx, 'Vertices')
        V = cx.Vertices;
    elseif isfield(cx, 'flat_cx') && isfield(cx.flat_cx, 'Vertices')
        V = cx.flat_cx.Vertices;
    else
        error('Expected cx.Vertices or cx.flat_cx.Vertices');
    end
    if ~isfield(cx, 'Faces'), error('Expected cx.Faces'); end
    F = cx.Faces;

 % ---------------- validate nodes/colors ----------------
    nodeXYZ = double(nodeXYZ);
    N = size(nodeXYZ,1);
    if size(nodeXYZ,2) ~= 3, error('nodeXYZ must be N x 3'); end
    if ~isequal(size(A), [N N]), error('A must be N x N'); end
    nodeColor = normalize_node_colors(nodeColor, N);

 % ---------------- figure/axes ----------------
    h.fig = figure('Color', opts.background, 'Renderer', opts.renderer, 'RendererMode', 'manual');
    try, opengl hardware; catch, end
    if isprop(h.fig, 'GraphicsSmoothing')
        h.fig.GraphicsSmoothing = 'on';
    end

    h.ax = axes('Parent', h.fig);
    hold(h.ax, 'on');
    axis(h.ax, 'vis3d');
    daspect(h.ax, [1 1 1]);
    if opts.axisOff, axis(h.ax, 'off'); end
    camproj(h.ax, opts.camProjection);

 % ---------------- cortex surface ----------------
    h.surface = patch('Faces', F, 'Vertices', V, ...
        'FaceColor', opts.surfaceColor, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', opts.surfaceAlpha, ...
        'FaceLighting', opts.faceLighting, ...
        'AmbientStrength', 0.28, ...
        'DiffuseStrength', 0.78, ...
        'SpecularStrength', opts.surfaceSpec, ...
        'SpecularExponent', opts.surfaceSpecExp, ...
        'BackFaceLighting', 'reverselit', ...
        'Parent', h.ax);

 % ---------------- choose edge list ----------------
    if ~isempty(opts.edgePairs)
        pairs = opts.edgePairs;
    else
        if opts.useUpperTri
            [ii, jj] = find(triu(A ~= 0, 1));
        else
            [ii, jj] = find(A ~= 0);
        end
        pairs = [ii, jj];
    end

    if size(pairs,1) > opts.maxEdges
        pairs = pairs(1:opts.maxEdges, :);
        warning('Too many edges; truncating to maxEdges=%d', opts.maxEdges);
    end

 % ---------------- edges (tubes) ----------------
    h.edges = gobjects(size(pairs,1), 1);
    for k = 1:size(pairs,1)
        i = pairs(k,1); j = pairs(k,2);
        p1 = nodeXYZ(i,:); p2 = nodeXYZ(j,:);

        if isempty(opts.edgeColor)
            eCol = 0.5*(nodeColor(i,:) + nodeColor(j,:)); % blended edge color
        else
            eCol = opts.edgeColor;
        end

        h.edges(k) = tube_between_points(h.ax, p1, p2, ...
            opts.edgeRadius, opts.edgeRes, eCol, opts.edgeAlpha, ...
            opts.edgeAmbient, opts.edgeDiffuse, opts.edgeSpec, opts.edgeSpecExp, ...
            opts.faceLighting);
    end

 % ---------------- nodes (spheres) ----------------
    h.nodes = gobjects(N,1);
    [sx, sy, sz] = sphere(opts.nodeRes);

    for i = 1:N
        r = opts.nodeRadius;
        xi = nodeXYZ(i,1); yi = nodeXYZ(i,2); zi = nodeXYZ(i,3);

        h.nodes(i) = surf(h.ax, r*sx + xi, r*sy + yi, r*sz + zi, ...
            'FaceColor', nodeColor(i,:), ...
            'EdgeColor', 'none', ...
            'FaceLighting', opts.faceLighting, ...
            'AmbientStrength', opts.nodeAmbient, ...
            'DiffuseStrength', opts.nodeDiffuse, ...
            'SpecularStrength', opts.nodeSpec, ...
            'SpecularExponent', opts.nodeSpecExp, ...
            'BackFaceLighting', 'reverselit');
    end

  % ---------------- view ----------------
    if ~isempty(opts.viewAngle)
        view(h.ax, opts.viewAngle(1), opts.viewAngle(2));
    end

    % ---------------- global lighting / material / shading ----------------
    lighting(h.ax, opts.lightingAlg);   % phong
    material(h.ax, opts.materialStyle); % dull
   %shading(h.ax, 'flat');    
    
    % ---------------- lights ----------------
    delete(findall(h.ax, 'Type', 'light'));
    h.lights = apply_light_preset(h.ax, opts);

    camva(h.ax, 7);
end

% ====== light preset ======
function L = apply_light_preset(ax, opts)
    L = gobjects(0);

    switch lower(opts.lightStyle)
        case 'right'
            % Main light from camera-right (camera-relative)
            L(1) = camlight(ax, 'right');
            set(L(1), 'Color', opts.lightColor);

            % Optional very weak fill to avoid over-dark areas
            if isfield(opts, 'addFillLight') && opts.addFillLight
                L(2) = camlight(ax, opts.fillLightStyle); % 'headlight' works well
                set(L(2), 'Color', opts.fillLightColor);
            end

        case 'headlight'
            L(1) = camlight(ax, 'headlight');
            set(L(1), 'Color', opts.lightColor);

        case 'tri'
            L(1) = camlight(ax, 'headlight'); set(L(1), 'Color', opts.lightColor);
            L(2) = camlight(ax,  30,  30);
            L(3) = camlight(ax, -30,  20);

        otherwise
            error('Unknown opts.lightStyle: %s', opts.lightStyle);
    end
end

% ====== tube between two points ======
function hTube = tube_between_points(ax, p1, p2, radius, nSides, faceColor, faceAlpha, ...
                                    amb, dif, spec, specExp, faceLighting)
    p1 = p1(:); p2 = p2(:);
    v = p2 - p1;
    L = norm(v);
    if L < 1e-12
        hTube = gobjects(1);
        return;
    end
    d = v / L;

    [X, Y, Z] = cylinder(radius, nSides);
    Z = Z * L;

    R = rot_from_z(d);
    P = R * [X(:)'; Y(:)'; Z(:)'];
    Xr = reshape(P(1,:), size(X)) + p1(1);
    Yr = reshape(P(2,:), size(Y)) + p1(2);
    Zr = reshape(P(3,:), size(Z)) + p1(3);

    hTube = surf(ax, Xr, Yr, Zr, ...
        'FaceColor', faceColor, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', faceAlpha, ...
        'FaceLighting', faceLighting, ...
        'AmbientStrength', amb, ...
        'DiffuseStrength', dif, ...
        'SpecularStrength', spec, ...
        'SpecularExponent', specExp, ...
        'BackFaceLighting', 'reverselit');
end

% ====== rotation from z to direction d ======
function R = rot_from_z(d)
    z = [0;0;1];
    d = d(:) / norm(d);

    c = dot(z, d);
    if abs(c - 1) < 1e-12
        R = eye(3); return;
    elseif abs(c + 1) < 1e-12
        R = [1 0 0; 0 -1 0; 0 0 -1]; return;
    end

    v = cross(z, d);
    s = norm(v);

    vx = [   0   -v(3)  v(2);
           v(3)   0    -v(1);
          -v(2)  v(1)   0   ];

    R = eye(3) + vx + (vx*vx) * ((1 - c) / (s^2));
end

% ====== defaults merge ======
function opts = apply_defaults(opts, d)
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
            opts.(f{i}) = d.(f{i});
        end
    end
end

% ====== node colors ======
function C = normalize_node_colors(nodeColor, N)
    if isempty(nodeColor)
        C = repmat([0.9 0.2 0.2], N, 1);
        return;
    end

    nodeColor = double(nodeColor);

    if isequal(size(nodeColor), [1 3])
        C = repmat(clamp01(nodeColor), N, 1);
        return;
    end

    if isequal(size(nodeColor), [N 3])
        C = clamp01(nodeColor);
        return;
    end

    if isequal(size(nodeColor), [N 1])
        vals = nodeColor(:);
        vals = (vals - min(vals)) / max(eps, (max(vals) - min(vals)));
        cmap = parula(256);
        idx = max(1, min(256, round(1 + vals*255)));
        C = cmap(idx, :);
        return;
    end

    error('nodeColor must be N x 3, 1 x 3, or N x 1');
end

function X = clamp01(X)
    X = max(0, min(1, X));
end
