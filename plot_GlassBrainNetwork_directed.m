function h = plot_GlassBrainNetwork_directed(cx, nodeXYZ, nodeColor, A, opts)

% Inputs:
%   cx         : struct with cx.Faces and cx.Vertices
%   nodeXYZ    : N x 3 node coordinates
%   nodeColor  : N x 3 RGB (0..1) OR 1 x 3 OR N x 1 scalar (mapped to parula)
%   A          : N x N adjacency matrix (1 = plot, 0 = skip)
%   opts       : struct with overrides (optional)

% Behavior:
%   - Draw ONE gray shaft between the two nodes (no duplicate shafts)
%   - If i -> j exists: draw an arrowhead at node j, colored by DRIVER node i
%   - If j -> i exists: draw an arrowhead at node i, colored by DRIVER node j
%   - If both directions exist: two arrowheads (one at each end), still ONE shaft


    if nargin < 5 || isempty(opts), opts = struct(); end

    % ---------------- defaults ----------------
    d.background      = 'w';
    d.renderer        = 'opengl';
    d.viewAngle       = [];
    d.ignoreDiagonal  = true;
    d.maxEdges        = inf;

    d.surfaceColor    = [0.82 0.82 0.82];
    d.surfaceAlpha    = 0.12;

    d.nodeRadius      = 0.003;
    d.nodeRes         = 36;

    d.edgeRadius      = 0.0005;
    d.edgeRes         = 20;                  % circular resolution for shaft/head
    d.edgeAlpha       = 0.85;
    d.edgeNeutral     = [0.25 0.25 0.25];

    d.headFrac        = 0.18;
    d.headLen         = [];                  % absolute head length (if set)
    d.headRadiusMul   = 2.2;
    d.headAlpha       = [];                  % default = edgeAlpha
    d.shaftIntoNodes  = true;                % shaft touches node centers (looks like "into the balls")

    opts = apply_defaults(opts, d);
    if isempty(opts.headAlpha), opts.headAlpha = opts.edgeAlpha; end

    % ---------------- cortex mesh ----------------
    if isfield(cx, 'Vertices')
        V = cx.Vertices;
    elseif isfield(cx, 'flat_cx') && isfield(cx.flat_cx, 'Vertices')
        V = cx.flat_cx.Vertices;
    else
        error('Expected cx.Vertices or cx.flat_cx.Vertices');
    end
    if ~isfield(cx, 'Faces'), error('Expected cx.Faces'); end
    F = cx.Faces;

    % ---------------- validate ----------------
    nodeXYZ = double(nodeXYZ);
    N = size(nodeXYZ,1);
    if size(nodeXYZ,2) ~= 3, error('nodeXYZ must be N x 3'); end
    if ~isequal(size(A), [N N]), error('A must be N x N'); end
    nodeColor = normalize_node_colors(nodeColor, N);

    Ause = (A ~= 0);
    if opts.ignoreDiagonal
        Ause(1:N+1:end) = 0;
    end

    % ---------------- figure/axes ----------------
    h.fig = figure('Color', opts.background, 'Renderer', opts.renderer, 'RendererMode', 'manual');
    try opengl hardware; catch, end
    if isprop(h.fig, 'GraphicsSmoothing'), h.fig.GraphicsSmoothing = 'on'; end

    h.ax = axes('Parent', h.fig);
    hold(h.ax, 'on');
    axis(h.ax, 'vis3d'); daspect(h.ax, [1 1 1]);
    axis(h.ax, 'off'); camproj(h.ax, 'perspective');

    % ---------------- cortex surface ----------------
    h.surface = patch('Faces', F, 'Vertices', V, ...
        'FaceColor', opts.surfaceColor, 'EdgeColor', 'none', ...
        'FaceAlpha', opts.surfaceAlpha, ...
        'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.28, 'DiffuseStrength', 0.78, ...
        'SpecularStrength', 0.03, 'SpecularExponent', 12, ...
        'BackFaceLighting', 'reverselit', ...
        'Parent', h.ax);

    % ---------------- nodes ----------------
    h.nodes = gobjects(N,1);
    [sx, sy, sz] = sphere(opts.nodeRes);
    for i = 1:N
        r  = opts.nodeRadius;
        c  = nodeColor(i,:);
        x  = nodeXYZ(i,1); y = nodeXYZ(i,2); z = nodeXYZ(i,3);

        h.nodes(i) = surf(h.ax, r*sx + x, r*sy + y, r*sz + z, ...
            'FaceColor', c, 'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud', ...
            'AmbientStrength', 0.12, 'DiffuseStrength', 0.88, ...
            'SpecularStrength', 0.35, 'SpecularExponent', 50, ...
            'BackFaceLighting', 'reverselit');
    end

    % ---------------- pairs (ONE shaft per unordered pair) ----------------
    P = triu(Ause | Ause.', 1);
    [ii, jj] = find(P);
    pairs = [ii, jj];

    if size(pairs,1) > opts.maxEdges
        pairs = pairs(1:opts.maxEdges, :);
        warning('Too many edges; truncating to maxEdges=%d', opts.maxEdges);
    end

    h.shafts = gobjects(size(pairs,1), 1);
    h.heads  = gobjects(0);

    headBaseR = opts.headRadiusMul * opts.edgeRadius;

    hh = 0; % head counter
    for k = 1:size(pairs,1)
        i = pairs(k,1);
        j = pairs(k,2);

        Ci = nodeXYZ(i,:);
        Cj = nodeXYZ(j,:);

        ij = Ause(i,j);     % i -> j
        ji = Ause(j,i);     % j -> i

        v = Cj - Ci;
        L = norm(v);
        if L < 1e-12
            continue;
        end
        u = v / L;          % from i to j

        % Surface points facing each other
        Pi_surf = Ci + u * opts.nodeRadius;
        Pj_surf = Cj - u * opts.nodeRadius;
        Lsurf   = norm(Pj_surf - Pi_surf);
        if Lsurf < 1e-12
            % Nodes overlap: skip arrowheads, draw nothing or a tiny stub
            continue;
        end

        % Arrowhead length
        if ~isempty(opts.headLen)
            headLen = opts.headLen;
        else
            headLen = opts.headFrac * Lsurf;
        end
        headLen = max(headLen, 0);
        headLen = min(headLen, 0.40 * Lsurf);  % keep reasonable
        if (ij && ji)
            % if both heads exist, ensure there's room for both
            headLen = min(headLen, 0.45 * Lsurf);
        end

        % Compute head geometry positions (tip on surface, base toward midline)
        % For i->j: head at j, axis +u, tip at Pj_surf, base at Pj_surf - u*headLen
        if ij
            tipJ  = Pj_surf;
            baseJ = Pj_surf - u*headLen;
        else
            baseJ = Pj_surf; % no head here
        end

        % For j->i: head at i, axis -u, tip at Pi_surf, base at Pi_surf + u*headLen
        if ji
            tipI  = Pi_surf;
            baseI = Pi_surf + u*headLen;
        else
            baseI = Pi_surf; % no head here
        end

        % Shaft endpoints:
        % - If shaftIntoNodes: extend to centers on ends that do NOT have a head;
        % - Always avoid running through the arrowhead volume (end at base of head).
        if ji
            shaftStart = baseI;
        else
            shaftStart = Ci;      % into node center
        end

        if ij
            shaftEnd = baseJ;
        else
            shaftEnd = Cj;        % into node center
        end

        % If user prefers shaft not into centers, clamp to surface points
        if ~opts.shaftIntoNodes
            if ~ji, shaftStart = Pi_surf; end
            if ~ij, shaftEnd   = Pj_surf; end
        end

        % Draw shaft if non-degenerate
        if norm(shaftEnd - shaftStart) > 1e-12
            h.shafts(k) = tube_between_points(h.ax, shaftStart, shaftEnd, ...
                opts.edgeRadius, opts.edgeRes, opts.edgeNeutral, opts.edgeAlpha);
        else
            h.shafts(k) = gobjects(1);
        end

        % Draw arrowheads (colored by DRIVER/source)
        if ij
            hh = hh + 1;
            cDriver = nodeColor(i,:); % driver i
            h.heads(hh,1) = cone_tip_at_point(h.ax, tipJ, +u, headLen, headBaseR, opts.edgeRes, cDriver, opts.headAlpha);
        end
        if ji
            hh = hh + 1;
            cDriver = nodeColor(j,:); % driver j
            h.heads(hh,1) = cone_tip_at_point(h.ax, tipI, -u, headLen, headBaseR, opts.edgeRes, cDriver, opts.headAlpha);
        end
    end

    % ---------------- view + lighting ----------------
    if ~isempty(opts.viewAngle)
        view(h.ax, opts.viewAngle(1), opts.viewAngle(2));
    end
    lighting(h.ax, 'phong');
    material(h.ax, 'dull');

    delete(findall(h.ax, 'Type', 'light'));
    h.lights = camlight(h.ax, 'right');
    set(h.lights, 'Color', [1 1 1]);

    camva(h.ax, 7);
end

% =====================================================================
% Solid-color tube (cylinder rotated + translated)
% =====================================================================
function hTube = tube_between_points(ax, p1, p2, radius, nSides, faceColor, faceAlpha)
    p1 = p1(:); p2 = p2(:);
    v  = p2 - p1;
    L  = norm(v);
    if L < 1e-12, hTube = gobjects(1); return; end
    d  = v / L;

    [X, Y, Z] = cylinder(radius, nSides);
    Z = Z * L;

    R = rot_from_z(d);
    P = R * [X(:)'; Y(:)'; Z(:)'];
    Xr = reshape(P(1,:), size(X)) + p1(1);
    Yr = reshape(P(2,:), size(Y)) + p1(2);
    Zr = reshape(P(3,:), size(Z)) + p1(3);

    hTube = surf(ax, Xr, Yr, Zr, ...
        'FaceColor', faceColor, 'EdgeColor', 'none', ...
        'FaceAlpha', faceAlpha, ...
        'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.10, 'DiffuseStrength', 0.90, ...
        'SpecularStrength', 0.15, 'SpecularExponent', 25, ...
        'BackFaceLighting', 'reverselit');
end

% =====================================================================
% Cone arrowhead with TIP at a point, oriented along direction d (unit)
% base is behind tip by headLen (i.e., basePoint = tip - d*headLen)
% =====================================================================
function hCone = cone_tip_at_point(ax, tipPoint, d, headLen, headBaseR, nSides, color, alpha)
    d = d(:);
    d = d / norm(d);

    % Cone in local coords: base at z=0, tip at z=headLen
    [X, Y, Z] = cylinder([headBaseR 0], nSides);
    Z = Z * headLen;

    % Place so that local tip (z=headLen) maps to tipPoint
    basePoint = tipPoint(:) - d * headLen;

    R = rot_from_z(d);
    P = R * [X(:)'; Y(:)'; Z(:)'];
    Xr = reshape(P(1,:), size(X)) + basePoint(1);
    Yr = reshape(P(2,:), size(Y)) + basePoint(2);
    Zr = reshape(P(3,:), size(Z)) + basePoint(3);

    hCone = surf(ax, Xr, Yr, Zr, ...
        'FaceColor', color, 'EdgeColor', 'none', ...
        'FaceAlpha', alpha, ...
        'FaceLighting', 'gouraud', ...
        'AmbientStrength', 0.10, 'DiffuseStrength', 0.90, ...
        'SpecularStrength', 0.20, 'SpecularExponent', 30, ...
        'BackFaceLighting', 'reverselit');
end

% =====================================================================
% Rotation matrix mapping +Z to direction d
% =====================================================================
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

% =====================================================================
% Defaults merge
% =====================================================================
function opts = apply_defaults(opts, d)
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
            opts.(f{i}) = d.(f{i});
        end
    end
end

% =====================================================================
% Node colors normalization
% =====================================================================
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

    error('nodeColor must be 1x3, Nx3, or Nx1');
end

function X = clamp01(X)
    X = max(0, min(1, X));
end
