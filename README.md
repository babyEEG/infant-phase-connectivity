# infant-phase-connectivity
MATLAB code implementing the analytical pipeline for 'Cortical bursts provide spatio-temporal frames for the large-scale phase synchrony emerging across the birth transition'. Includes the infant head model; PAC, NPPC and PPC connectivity analyses; and network visualisation.

The main function is **compute_connectivity.m** which does the following:
- Loads example EEG data
- Filters EEG into: delta, theta, alpha, beta fr. bands
- Reconstructs cortical source activity using the infant head model
- Computes phase-phase correlation (PPC) using phase-locking value (PLV)
- Computes phase-amplitude coupling (PAC), including local (l-PAC = diagonal) and distant (d-PAC = off-diagonal)
- Computes nested phase-phase correlation (NPPC)
- Visualises directed and undirected networks on the glass brain

Folder **HeadModel** contains surfaces, 124ch EEG cap, Inverse/Collapse operators

Folder **Filters** contains digital filters for delta, theta, alpha, beta fr.bands
Note! Filters were designed for EEG signals with sampling rate 100Hz

Function **get_top_connections.m** selects the top n% of connections from connectivity matrices  
