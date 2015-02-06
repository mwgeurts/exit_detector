function widths = CalcFieldWidth(plan)
% CalcFieldWidth computes the jaw positions and field width at each
% projection for a given delivery plan structure.  The return variable
% includes the front jaw, back jaw, and field widths as defined below.  The
% values are in centimeters projected to isocenter.
%
% The following variables are required for proper execution: 
%   plan: delivery plan data including scale, tau, lower leaf index,
%       number of projections, number of leaves, sync/unsync actions, 
%       leaf sinogram, and planTrialUID. See LoadPlan.m for more detail.
%
% The following variables are returned upon succesful completion:
%   widths: 3 x n vector of field widths, where n is the total number of
%       projections (defined by plan.totalTau + 1), widths(1,:) are the 
%       positions of the front jaw, widths(2,:) the back jaw, and
%       widths(3,:) are the the field widths
% 
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Execute in try/catch statement
try  
    
% Total tau and event data are required for field width computation
if isfield(plan, 'totalTau') && isfield(plan, 'events')
    
% Log start
Event('Computing jaw profiles using delivery plan events');
tic;
    
% Initialize return variable
widths = zeros(3, plan.totalTau);

% Loop through each event
for i = 1:size(plan.events,1)
    
    % If a jaw front event
    if strcmp(plan.events{i,2}, 'jawFront')
        
        % Set all future projections to the specified front jaw
        widths(1, ceil(plan.events{i,1})+1:plan.totalTau+1) = ...
            ones(1, plan.totalTau - ceil(plan.events{i,1}) + 1) * ...
            plan.events{i,3};
       
    % Otherwise if a jaw back event
    elseif strcmp(plan.events{i,2}, 'jawBack')
        
        % Set all future projections to the specified back jaw
        widths(2, ceil(plan.events{i,1})+1:plan.totalTau+1) = ...
            ones(1, plan.totalTau - ceil(plan.events{i,1}) + 1) * ...
            plan.events{i,3};
        
    % Otherwise if a jaw front rate event
    elseif strcmp(plan.events{i,2}, 'jawFrontRate')
        
        % Set all future projections to the current front jaw position plus
        % the specified front jaw rate multiplied by number of projections
        widths(1, ceil(plan.events{i,1})+1:plan.totalTau+1) = ...
            interp1([floor(plan.events{i,1}) ceil(plan.events{i,1}+1e-10)], ...
            widths(1, floor(plan.events{i,1})+1:ceil(plan.events{i,1}+1e-10)+1), ...
            plan.events{i,1}) + ((ceil(plan.events{i,1}):plan.totalTau) - ...
            plan.events{i,1}) * plan.events{i,3};
        
    % Otherwise if a jaw back event
    elseif strcmp(plan.events{i,2}, 'jawBackRate')
        
        % Set all future projections to the current back jaw position plus
        % the specified back jaw rate multiplied by number of projections
        widths(2, ceil(plan.events{i,1})+1:plan.totalTau+1) = ...
            interp1([floor(plan.events{i,1}) ceil(plan.events{i,1}+1e-10)], ...
            widths(2, floor(plan.events{i,1})+1:ceil(plan.events{i,1}+1e-10)+1), ...
            plan.events{i,1}) + ((ceil(plan.events{i,1}):plan.totalTau) - ...
            plan.events{i,1}) * plan.events{i,3};
    end
end

% Multiply by 85 cm to project to iso
widths = widths * 85;

% Compute field width as difference between front and back
widths(3,:) = widths(1,:) - widths(2,:);

% Log completion
Event(sprintf('Jaw profiles computed successfully in %0.3f seconds', toc));

end

% Catch errors, log, and rethrow
catch err
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end