function B = get_top_connections(A, top_percent)

% Inputs:
%   A           : square connectivity matrix [ch x ch]
%   top_percent : percentage of strongest connections
%                 e.g. 1 = top 1%, 5 = top 5%
%
% Output:
%   B           : binary matrix
%                 1 = connection belongs to strongest top_percent
%                 0 = otherwise
%
% Notes:
%   - Diagonal is always ignored.
%   - If A is symmetric, only unique upper-triangular connections are ranked.
%   - If A is asymmetric, all off-diagonal directed connections are ranked.

    if size(A,1) ~= size(A,2)
        error('A must be a square matrix');
    end

    if top_percent <= 0 || top_percent > 100
        error('top_percent must be > 0 and <= 100');
    end

  % Check symmetry
    isSym = issymmetric(A);

    if isSym

      % Unique off-diagonal connections
        mask = triu(true(size(A)), 1);

    else

      % All directed off-diagonal connections
        mask = ~eye(size(A));

    end

    vals = A(mask);

  % Number of strongest connections to retain
    N = max(1, round((top_percent/100) * numel(vals)));

  % Find strongest connections
    [~, idx] = maxk(vals, N);

  % Binary matrix
    B = false(size(A));

    ind = find(mask);
    B(ind(idx)) = true;

  % Restore symmetry if input was symmetric
    if isSym
        B = B | B.';
    end

    B = double(B);

end