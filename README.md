# Sigma

FPGA implementation of sigma-point class of non-linear Gaussian filters, 
namely Unscented Kalman Filter (UKF), Cubature Kalman Filter (CKF), Cubature 
Quadrature Kalman Filter (CQKF) and Gauss Hermite Filter (GHF). Currently 
targeted towards Xilinx Zynq-7000 (ZC702) and Digilent Nexys4 DDR boards.

The intuition behind sigma-point class of filters is founded on the principle 
that it is easier to approximate a probability distribution than it is to 
approximate an arbitrary non-linear function or transformation. The members 
of this class of filters accomplish the approximation of a probability 
distribution by deterministically "sampling" support points (called sigma 
points) and assigning weight to each of these points. The mean and covariance 
can then be computed based on the statistics of these "sigma" points.

The implementation uses proprietary Xilinx IP for now and they come with 
their own set of copyright notices. The aim is to move away from proprietary 
IP and switch to open-source alternatives.

This work is done, under the supervision of Dr Shovan Bhaumik (Associate 
Professor, Dept of Electrical Engineering, Indian Institute of Technology 
Patna), for the partial fulfilment of requirements towards the award 
of a Bachelors degree. Please feel free to get in touch with the author, 
Hatim Kanchwala <me@hatimak.me>, for any details.

