#ifndef AP_AHRS_DCM_H
#define AP_AHRS_DCM_H
/*
  DCM based AHRS (Attitude Heading Reference System) interface for
  ArduPilot

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.
*/

class AP_AHRS_DCM : public AP_AHRS
{
public:
	// Constructors
	AP_AHRS_DCM(IMU *imu, GPS *&gps) : AP_AHRS(imu, gps)
	{
		_dcm_matrix.identity();

		// these are experimentally derived from the simulator
		// with large drift levels
                _ki = 0.0087;
		_ki_yaw = 0.01;

                _kp.set(0.4);
		_kp_yaw.set(0.4);
	}

	// return the smoothed gyro vector corrected for drift
	Vector3f	get_gyro(void) {return _omega + _omega_P + _omega_yaw_P; }
	Matrix3f	get_dcm_matrix(void) {return _dcm_matrix; }

	// return the current drift correction integrator value
	Vector3f	get_gyro_drift(void) {return _omega_I; }

	// Methods
	void 		update(void);
	void 		reset(bool recover_eulers = false);

	// status reporting
	float		get_error_rp(void);
	float		get_error_yaw(void);

	// settable parameters
	AP_Float	_kp_yaw;
	AP_Float	_kp;

private:
	float		_ki;
	float		_ki_yaw;
	bool		_have_initial_yaw;

	// Methods
	void 		matrix_update(float _G_Dt);
	void 		normalize(void);
	void		check_matrix(void);
	bool	 	renorm(Vector3f const &a, Vector3f &result);
	void 		drift_correction(float deltat);
	void 		drift_correction_yaw(void);
	float		yaw_error_compass();
	float		yaw_error_gps();
	void 		euler_angles(void);

	// primary representation of attitude
	Matrix3f	_dcm_matrix;

	Vector3f 	_gyro_vector;		// Store the gyros turn rate in a vector
	Vector3f 	_accel_vector;		// current accel vector

	Vector3f	_omega_P;		// accel Omega proportional correction
	Vector3f	_omega_yaw_P;		// proportional yaw correction
	Vector3f 	_omega_I;		// Omega Integrator correction
	Vector3f	_omega_I_sum;
	float		_omega_I_sum_time;
	Vector3f 	_omega;			// Corrected Gyro_Vector data

	// P term gain based on spin rate
	float 		_P_gain(float spin_rate);

	// state to support status reporting
	float		_renorm_val_sum;
	uint16_t	_renorm_val_count;
	float		_error_rp_sum;
	uint16_t	_error_rp_count;
	float		_error_rp_last;
	float		_error_yaw_sum;
	uint16_t	_error_yaw_count;
	float		_error_yaw_last;

	// time in millis when we last got a GPS heading
	uint32_t	_gps_last_update;

	// state of accel drift correction
	Vector3f	_ra_sum;
	Vector3f	_last_velocity;
	float		_ra_deltat;
	uint32_t	_ra_sum_start;

	// current drift error in earth frame
	Vector3f	_drift_error_earth;

	// whether we have GPS lock
	bool		_have_gps_lock;
};

#endif // AP_AHRS_DCM_H
