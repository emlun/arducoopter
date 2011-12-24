// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

#if LOGGING_ENABLED == ENABLED

// Code to Write and Read packets from DataFlash log memory
// Code to interact with the user to dump or erase logs

#define HEAD_BYTE1 	0xA3	// Decimal 163
#define HEAD_BYTE2 	0x95	// Decimal 149
#define END_BYTE	0xBA	// Decimal 186


// These are function definitions so the Menu can be constructed before the functions
// are defined below. Order matters to the compiler.
static bool     print_log_menu(void);
static int8_t	dump_log(uint8_t argc, 			const Menu::arg *argv);
static int8_t	erase_logs(uint8_t argc, 		const Menu::arg *argv);
static int8_t	select_logs(uint8_t argc, 		const Menu::arg *argv);

// This is the help function
// PSTR is an AVR macro to read strings from flash memory
// printf_P is a version of print_f that reads from flash memory
//static int8_t	help_log(uint8_t argc, 			const Menu::arg *argv)
/*{
	Serial.printf_P(PSTR("\n"
						 "Commands:\n"
						 "  dump <n>"
						 "  erase (all logs)\n"
						 "  enable <name> | all\n"
						 "  disable <name> | all\n"
						 "\n"));
    return 0;
}*/

// Creates a constant array of structs representing menu options
// and stores them in Flash memory, not RAM.
// User enters the string in the console to call the functions on the right.
// See class Menu in AP_Coommon for implementation details
const struct Menu::command log_menu_commands[] PROGMEM = {
	{"dump",	dump_log},
	{"erase",	erase_logs},
	{"enable",	select_logs},
	{"disable",	select_logs}
};

// A Macro to create the Menu
MENU2(log_menu, "Log", log_menu_commands, print_log_menu);

static void get_log_boundaries(byte log_num, int & start_page, int & end_page);

static bool
print_log_menu(void)
{
	int log_start;
	int log_end;
	int temp;
	int last_log_num = find_last_log();

	uint16_t num_logs = get_num_logs();

	Serial.printf_P(PSTR("logs enabled: "));

	if (0 == g.log_bitmask) {
		Serial.printf_P(PSTR("none"));
	}else{
		if (g.log_bitmask & MASK_LOG_ATTITUDE_FAST)	Serial.printf_P(PSTR(" ATTITUDE_FAST"));
		if (g.log_bitmask & MASK_LOG_ATTITUDE_MED)	Serial.printf_P(PSTR(" ATTITUDE_MED"));
		if (g.log_bitmask & MASK_LOG_GPS)			Serial.printf_P(PSTR(" GPS"));
		if (g.log_bitmask & MASK_LOG_PM)			Serial.printf_P(PSTR(" PM"));
		if (g.log_bitmask & MASK_LOG_CTUN)			Serial.printf_P(PSTR(" CTUN"));
		if (g.log_bitmask & MASK_LOG_NTUN)			Serial.printf_P(PSTR(" NTUN"));
		if (g.log_bitmask & MASK_LOG_RAW)			Serial.printf_P(PSTR(" RAW"));
		if (g.log_bitmask & MASK_LOG_CMD)			Serial.printf_P(PSTR(" CMD"));
		if (g.log_bitmask & MASK_LOG_CUR)			Serial.printf_P(PSTR(" CURRENT"));
		if (g.log_bitmask & MASK_LOG_MOTORS)		Serial.printf_P(PSTR(" MOTORS"));
		if (g.log_bitmask & MASK_LOG_OPTFLOW)		Serial.printf_P(PSTR(" OPTFLOW"));
	}

	Serial.println();

	if (num_logs == 0) {
		Serial.printf_P(PSTR("\nNo logs\n\n"));
	}else{
		Serial.printf_P(PSTR("\n%d logs\n"), num_logs);

		for(int i=num_logs;i>=1;i--) {
            int last_log_start = log_start, last_log_end = log_end;
			temp = last_log_num-i+1;
			get_log_boundaries(temp, log_start, log_end);
			Serial.printf_P(PSTR("Log %d,    start %d,   end %d\n"), temp, log_start, log_end);
            if (last_log_start == log_start && last_log_end == log_end) {
                // we are printing bogus logs
                break;
            }
		}
		Serial.println();
	}
	return(true);
}

static int8_t
dump_log(uint8_t argc, const Menu::arg *argv)
{
	int dump_log;
	int dump_log_start;
	int dump_log_end;
	byte last_log_num;

	// check that the requested log number can be read
	dump_log = argv[1].i;
	last_log_num = find_last_log();

	if (dump_log == -2) {
		for(int count=1; count<=DF_LAST_PAGE; count++) {
			DataFlash.StartRead(count);
			Serial.printf_P(PSTR("DF page, log file #, log page: %d,\t"), count);
			Serial.printf_P(PSTR("%d,\t"), DataFlash.GetFileNumber());
			Serial.printf_P(PSTR("%d\n"), DataFlash.GetFilePage());
		}
		return(-1);
	} else if (dump_log <= 0) {
		Serial.printf_P(PSTR("dumping all\n"));
		Log_Read(1, DF_LAST_PAGE);
		return(-1);
	} else if ((argc != 2) || (dump_log <= (last_log_num - get_num_logs())) || (dump_log > last_log_num)) {
		Serial.printf_P(PSTR("bad log number\n"));
		return(-1);
	}

	get_log_boundaries(dump_log, dump_log_start, dump_log_end);
	/*Serial.printf_P(PSTR("Dumping Log number %d,    start %d,   end %d\n"),
				  dump_log,
				  dump_log_start,
				  dump_log_end);
	*/
	Log_Read(dump_log_start, dump_log_end);
	//Serial.printf_P(PSTR("Done\n"));
	return (0);
}

static void
do_erase_logs(void (*delay_cb)(unsigned long))
{
	Serial.printf_P(PSTR("\nErasing log...\n"));
	DataFlash.SetFileNumber(0xFFFF);
	for(int j = 1; j <= DF_LAST_PAGE; j++) {
		DataFlash.PageErase(j);
		DataFlash.StartWrite(j);		// We need this step to clean FileNumbers
		if(j%128 == 0) Serial.printf_P(PSTR("+"));
        delay_cb(1);
	}

	Serial.printf_P(PSTR("\nLog erased.\n"));
	DataFlash.FinishWrite();
}

static int8_t
erase_logs(uint8_t argc, const Menu::arg *argv)
{
    do_erase_logs(delay);
    return 0;
}

static int8_t
select_logs(uint8_t argc, const Menu::arg *argv)
{
	uint16_t	bits;

	if (argc != 2) {
		Serial.printf_P(PSTR("missing log type\n"));
		return(-1);
	}

	bits = 0;

	// Macro to make the following code a bit easier on the eye.
	// Pass it the capitalised name of the log option, as defined
	// in defines.h but without the LOG_ prefix.  It will check for
	// that name as the argument to the command, and set the bit in
	// bits accordingly.
	//
	if (!strcasecmp_P(argv[1].str, PSTR("all"))) {
		bits = ~0;
	} else {
		#define TARG(_s)	if (!strcasecmp_P(argv[1].str, PSTR(#_s))) bits |= MASK_LOG_ ## _s
		TARG(ATTITUDE_FAST);
		TARG(ATTITUDE_MED);
		TARG(GPS);
		TARG(PM);
		TARG(CTUN);
		TARG(NTUN);
		TARG(MODE);
		TARG(RAW);
		TARG(CMD);
		TARG(CUR);
		TARG(MOTORS);
		TARG(OPTFLOW);
		#undef TARG
	}

	if (!strcasecmp_P(argv[0].str, PSTR("enable"))) {
		g.log_bitmask.set_and_save(g.log_bitmask | bits);
	}else{
		g.log_bitmask.set_and_save(g.log_bitmask & ~bits);
	}

	return(0);
}

static int8_t
process_logs(uint8_t argc, const Menu::arg *argv)
{
	log_menu.run();
	return 0;
}



// This function determines the number of whole or partial log files in the DataFlash
// Wholly overwritten files are (of course) lost.
static byte get_num_logs(void)
{
	uint16_t lastpage;
	uint16_t last;
	uint16_t first;

	if(find_last_page() == 1) return 0;

	DataFlash.StartRead(1);

	if(DataFlash.GetFileNumber() == 0XFFFF) return 0;

	lastpage = find_last_page();
	DataFlash.StartRead(lastpage);
	last = DataFlash.GetFileNumber();
	DataFlash.StartRead(lastpage + 2);
	first = DataFlash.GetFileNumber();
	if(first > last) {
		DataFlash.StartRead(1);
		first = DataFlash.GetFileNumber();
	}
	if(last == first)
	{
		return 1;
	} else {
		return (last - first + 1);
	}
}

// This function starts a new log file in the DataFlash
static void start_new_log()
{
	uint16_t	last_page = find_last_page();

	DataFlash.StartRead(last_page);
	//Serial.print("last page: ");	Serial.println(last_page);
	//Serial.print("file #: ");	Serial.println(DataFlash.GetFileNumber());
	//Serial.print("file page: ");	Serial.println(DataFlash.GetFilePage());

	if(find_last_log() == 0 || DataFlash.GetFileNumber() == 0xFFFF) {
		DataFlash.SetFileNumber(1);
		DataFlash.StartWrite(1);
		//Serial.println("start log from 0");
		return;
	}

	// Check for log of length 1 page and suppress
	if(DataFlash.GetFilePage() <= 1) {
		DataFlash.SetFileNumber(DataFlash.GetFileNumber());		// Last log too short, reuse its number
		DataFlash.StartWrite(last_page);					// and overwrite it
		//Serial.println("start log from short");
	} else {
		if(last_page == 0xFFFF) last_page=0;
		DataFlash.SetFileNumber(DataFlash.GetFileNumber()+1);
		DataFlash.StartWrite(last_page + 1);
		//Serial.println("start log normal");
	}
}

// This function finds the first and last pages of a log file
// The first page may be greater than the last page if the DataFlash has been filled and partially overwritten.
static void get_log_boundaries(byte log_num, int & start_page, int & end_page)
{
	int num = get_num_logs();
	int look;
	if(num == 1)
	{
		DataFlash.StartRead(DF_LAST_PAGE);
		if(DataFlash.GetFileNumber() == 0xFFFF)
		{
			start_page = 1;
			end_page = find_last_page_of_log((uint16_t)log_num);
		} else {
			end_page = find_last_page_of_log((uint16_t)log_num);
			start_page = end_page + 1;
		}

	} else {
		if(log_num==1) {
			DataFlash.StartRead(DF_LAST_PAGE);
			if(DataFlash.GetFileNumber() == 0xFFFF) {
				start_page = 1;
			} else {
				start_page = find_last_page() + 1;
			}
		 } else {
			if(log_num == find_last_log() - num + 1) {
				start_page = find_last_page() + 1;
			} else {
				look = log_num-1;
				do {
				start_page = find_last_page_of_log(look) + 1;
				look--;
				} while (start_page <= 0 && look >=1);
			}
		}
	}
	if(start_page == DF_LAST_PAGE+1 || start_page == 0) start_page=1;
	end_page = find_last_page_of_log((uint16_t)log_num);
	if(end_page <= 0) end_page = start_page;
}

static bool check_wrapped(void)
{
	DataFlash.StartRead(DF_LAST_PAGE);
	if(DataFlash.GetFileNumber() == 0xFFFF)
		return 0;
	else
		return 1;
}

// This funciton finds the last log number
static int find_last_log(void)
{
	int last_page = find_last_page();
	DataFlash.StartRead(last_page);
	return DataFlash.GetFileNumber();
}

// This function finds the last page of the last file
static int find_last_page(void)
{
uint16_t look;
uint16_t bottom = 1;
uint16_t top = DF_LAST_PAGE;
uint32_t look_hash;
uint32_t bottom_hash;
uint32_t top_hash;

		DataFlash.StartRead(bottom);
		bottom_hash = (long)DataFlash.GetFileNumber()<<16 | DataFlash.GetFilePage();

		while(top-bottom > 1)
		{
			look = (top+bottom)/2;
			DataFlash.StartRead(look);
			look_hash = (long)DataFlash.GetFileNumber()<<16 | DataFlash.GetFilePage();
			if (look_hash >= 0xFFFF0000) look_hash = 0;

			if(look_hash < bottom_hash) {
				// move down
				top = look;
			} else {
				// move up
				bottom = look;
				bottom_hash = look_hash;
			}
		}

		DataFlash.StartRead(top);
		top_hash = (long)DataFlash.GetFileNumber()<<16 | DataFlash.GetFilePage();
		if (top_hash >= 0xFFFF0000) top_hash = 0;
		if (top_hash > bottom_hash)
		{
			return top;
		} else {
			return bottom;
		}
}

// This function finds the last page of a particular log file
static int find_last_page_of_log(uint16_t log_number)
{

uint16_t look;
uint16_t bottom;
uint16_t top;
uint32_t look_hash;
uint32_t check_hash;

	if(check_wrapped())
	{
		DataFlash.StartRead(1);
		bottom = DataFlash.GetFileNumber();
		if (bottom > log_number)
		{
			bottom = find_last_page();
			top = DF_LAST_PAGE;
		} else {
			bottom = 1;
			top = find_last_page();
		}
	} else {
		bottom = 1;
		top = find_last_page();
	}

	check_hash = (long)log_number<<16 | 0xFFFF;
	while(top-bottom > 1)
	{
		look = (top+bottom)/2;
		DataFlash.StartRead(look);
		look_hash = (long)DataFlash.GetFileNumber()<<16 | DataFlash.GetFilePage();
		if (look_hash >= 0xFFFF0000) look_hash = 0;

		if(look_hash > check_hash) {
			// move down
			top = look;
		} else {
			// move up
			bottom = look;
		}
	}

	DataFlash.StartRead(top);
	if (DataFlash.GetFileNumber() == log_number) return top;

	DataFlash.StartRead(bottom);
	if (DataFlash.GetFileNumber() == log_number) return bottom;

	return -1;
}



// Write an GPS packet. Total length : 30 bytes
static void Log_Write_GPS()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_GPS_MSG);

	DataFlash.WriteLong(g_gps->time);						// 1
	DataFlash.WriteByte(g_gps->num_sats);					// 2

	DataFlash.WriteLong(current_loc.lat);					// 3
	DataFlash.WriteLong(current_loc.lng);					// 4
	DataFlash.WriteLong(current_loc.alt);					// 5
	DataFlash.WriteLong(g_gps->altitude);					// 6

	DataFlash.WriteInt(g_gps->ground_speed);				// 7
	DataFlash.WriteLong(g_gps->ground_course);		// 8

	DataFlash.WriteByte(END_BYTE);
}

// Read a GPS packet
static void Log_Read_GPS()
{
	int32_t temp1 	= DataFlash.ReadLong();			// 1 time
	int8_t temp2 	= DataFlash.ReadByte();			// 2 sats
	float temp3 	= DataFlash.ReadLong() / t7;	// 3 lat
	float temp4 	= DataFlash.ReadLong() / t7;	// 4 lon
	float temp5 	= DataFlash.ReadLong() / 100.0;	// 5 gps alt
	float temp6 	= DataFlash.ReadLong() / 100.0;	// 6 sensor alt
	int16_t temp7 	= DataFlash.ReadInt();			// 7 ground speed
	int32_t temp8 	= DataFlash.ReadLong();// 8 ground course

							//  1   2    3      4     5      6      7    8
	Serial.printf_P(PSTR("GPS, %ld, %d, %4.7f, %4.7f, %4.4f, %4.4f, %d, %ld\n"),
							temp1,		// 1 time
							temp2,		// 2 sats
							temp3,		// 3 lat
							temp4,		// 4 lon
							temp5,		// 5 gps alt
							temp6,		// 6 sensor alt
							temp7,		// 7 ground speed
							temp8);		// 8 ground course
}

// Write an raw accel/gyro data packet. Total length : 28 bytes
static void Log_Write_Raw()
{
	Vector3f gyro = imu.get_gyro();
	Vector3f accel = imu.get_accel();
	//Vector3f accel_filt	= imu.get_accel_filtered();

	gyro *= t7;								// Scale up for storage as long integers
	accel *= t7;
	//accel_filt *= t7;

	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_RAW_MSG);

	DataFlash.WriteLong(gyro.x);
	DataFlash.WriteLong(gyro.y);
	DataFlash.WriteLong(gyro.z);


	//DataFlash.WriteLong(accels_rot.x * t7);
	//DataFlash.WriteLong(accels_rot.y * t7);
	//DataFlash.WriteLong(accels_rot.z * t7);

	DataFlash.WriteLong(accel.x);
	DataFlash.WriteLong(accel.y);
	DataFlash.WriteLong(accel.z);

	DataFlash.WriteByte(END_BYTE);
}

// Read a raw accel/gyro packet
static void Log_Read_Raw()
{
	float logvar;
	Serial.printf_P(PSTR("RAW,"));
	for (int y = 0; y < 6; y++) {
		logvar = (float)DataFlash.ReadLong() / t7;
		Serial.print(logvar);
		Serial.print(comma);
	}
	Serial.println(" ");
}

static void Log_Write_Current()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_CURRENT_MSG);

	DataFlash.WriteInt(g.rc_3.control_in);			// 1
	DataFlash.WriteLong(throttle_integrator);		// 2
	DataFlash.WriteInt(battery_voltage 	* 100.0);	// 3
	DataFlash.WriteInt(current_amps 	* 100.0);	// 4
	DataFlash.WriteInt(current_total);				// 5

	DataFlash.WriteByte(END_BYTE);
}

// Read a Current packet
static void Log_Read_Current()
{
	int16_t temp1 = DataFlash.ReadInt();			// 1
	int32_t	temp2 = DataFlash.ReadLong();			// 2
	float 	temp3 = DataFlash.ReadInt() / 100.f;	// 3
	float 	temp4 = DataFlash.ReadInt() / 100.f;	// 4
	int16_t temp5 = DataFlash.ReadInt();			// 5

							//  1    2    3      4      5
	Serial.printf_P(PSTR("CURR, %d, %ld, %4.4f, %4.4f, %d\n"),
		temp1,
		temp2,
		temp3,
		temp4,
		temp5);
}

static void Log_Write_Motors()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_MOTORS_MSG);

	#if FRAME_CONFIG ==	TRI_FRAME
	DataFlash.WriteInt(motor_out[CH_1]);//1
	DataFlash.WriteInt(motor_out[CH_2]);//2
	DataFlash.WriteInt(motor_out[CH_4]);//3
	DataFlash.WriteInt(g.rc_4.radio_out);//4

	#elif FRAME_CONFIG == HEXA_FRAME
	DataFlash.WriteInt(motor_out[CH_1]);//1
	DataFlash.WriteInt(motor_out[CH_2]);//2
	DataFlash.WriteInt(motor_out[CH_3]);//3
	DataFlash.WriteInt(motor_out[CH_4]);//4
	DataFlash.WriteInt(motor_out[CH_7]);//5
	DataFlash.WriteInt(motor_out[CH_8]);//6

	#elif FRAME_CONFIG == Y6_FRAME
	//left
	DataFlash.WriteInt(motor_out[CH_2]);//1
	DataFlash.WriteInt(motor_out[CH_3]);//2
	//right
	DataFlash.WriteInt(motor_out[CH_7]);//3
	DataFlash.WriteInt(motor_out[CH_1]);//4
	//back
	DataFlash.WriteInt(motor_out[CH_8]);//5
	DataFlash.WriteInt(motor_out[CH_4]);//6

	#elif FRAME_CONFIG == OCTA_FRAME || FRAME_CONFIG == OCTA_QUAD_FRAME
	DataFlash.WriteInt(motor_out[CH_1]);//1
	DataFlash.WriteInt(motor_out[CH_2]);//2
	DataFlash.WriteInt(motor_out[CH_3]);//3
	DataFlash.WriteInt(motor_out[CH_4]);//4
	DataFlash.WriteInt(motor_out[CH_7]);//5
	DataFlash.WriteInt(motor_out[CH_8]); //6
	DataFlash.WriteInt(motor_out[CH_10]);//7
	DataFlash.WriteInt(motor_out[CH_11]);//8

	#elif FRAME_CONFIG == HELI_FRAME
	DataFlash.WriteInt(heli_servo_out[0]);//1
	DataFlash.WriteInt(heli_servo_out[1]);//2
	DataFlash.WriteInt(heli_servo_out[2]);//3
	DataFlash.WriteInt(heli_servo_out[3]);//4
	DataFlash.WriteInt(g.heli_ext_gyro_gain);//5

	#else // quads
	DataFlash.WriteInt(motor_out[CH_1]);//1
	DataFlash.WriteInt(motor_out[CH_2]);//2
	DataFlash.WriteInt(motor_out[CH_3]);//3
	DataFlash.WriteInt(motor_out[CH_4]);//4
	#endif

	DataFlash.WriteByte(END_BYTE);
}

// Read a Current packet
static void Log_Read_Motors()
{
	#if FRAME_CONFIG == HEXA_FRAME || FRAME_CONFIG == Y6_FRAME
	int16_t temp1 = DataFlash.ReadInt();			// 1
	int16_t	temp2 = DataFlash.ReadInt();			// 2
	int16_t temp3 = DataFlash.ReadInt();			// 3
	int16_t temp4 = DataFlash.ReadInt();			// 4
	int16_t temp5 = DataFlash.ReadInt();			// 5
	int16_t temp6 = DataFlash.ReadInt();			// 6
							  // 1  2   3   4   5   6
	Serial.printf_P(PSTR("MOT, %d, %d, %d, %d, %d, %d\n"),
			temp1,	//1
			temp2,	//2
			temp3,	//3
			temp4,	//4
			temp5,	//5
			temp6);	//6

	#elif FRAME_CONFIG == OCTA_FRAME || FRAME_CONFIG == OCTA_QUAD_FRAME
	int16_t temp1 = DataFlash.ReadInt();			// 1
	int16_t	temp2 = DataFlash.ReadInt();			// 2
	int16_t temp3 = DataFlash.ReadInt();			// 3
	int16_t temp4 = DataFlash.ReadInt();			// 4
	int16_t temp5 = DataFlash.ReadInt();			// 5
	int16_t temp6 = DataFlash.ReadInt();			// 6
	int16_t temp7 = DataFlash.ReadInt();			// 7
	int16_t temp8 = DataFlash.ReadInt();			// 8
							 // 1   2   3   4   5   6   7   8
	Serial.printf_P(PSTR("MOT, %d, %d, %d, %d, %d, %d, %d, %d\n"),
			temp1,	//1
			temp2,	//2
			temp3,	//3
			temp4,	//4
			temp5,	//5
			temp6,	//6
			temp7,	//7
			temp8);	//8

	#elif FRAME_CONFIG == HELI_FRAME
	int16_t temp1 = DataFlash.ReadInt();			// 1
	int16_t	temp2 = DataFlash.ReadInt();			// 2
	int16_t temp3 = DataFlash.ReadInt();			// 3
	int16_t temp4 = DataFlash.ReadInt();			// 4
	int16_t temp5 = DataFlash.ReadInt();			// 5
							 // 1   2   3   4   5
	Serial.printf_P(PSTR("MOT, %d, %d, %d, %d, %d\n"),
			temp1,	//1
			temp2,	//2
			temp3,	//3
			temp4,	//4
			temp5);	//5

	#else // quads, TRIs
	int16_t temp1 = DataFlash.ReadInt();			// 1
	int16_t	temp2 = DataFlash.ReadInt();			// 2
	int16_t temp3 = DataFlash.ReadInt();			// 3
	int16_t temp4 = DataFlash.ReadInt();			// 4

							 // 1   2   3   4
	Serial.printf_P(PSTR("MOT, %d, %d, %d, %d\n"),
			temp1, 	//1
			temp2, 	//2
			temp3, 	//3
			temp4); //4;
	#endif
}

// Write an optical flow packet. Total length : 18 bytes
static void Log_Write_Optflow()
{
	#ifdef OPTFLOW_ENABLED
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_OPTFLOW_MSG);
	DataFlash.WriteInt((int)optflow.dx);
	DataFlash.WriteInt((int)optflow.dy);
	DataFlash.WriteInt((int)optflow.surface_quality);
	DataFlash.WriteLong(optflow.vlat);//optflow_offset.lat + optflow.lat);
	DataFlash.WriteLong(optflow.vlon);//optflow_offset.lng + optflow.lng);
	DataFlash.WriteByte(END_BYTE);
	#endif
}



static void Log_Read_Optflow()
{
	#ifdef OPTFLOW_ENABLED
	int16_t temp1 	= DataFlash.ReadInt();			// 1
	int16_t temp2 	= DataFlash.ReadInt();			// 2
	int16_t temp3 	= DataFlash.ReadInt();			// 3
	float temp4 	= DataFlash.ReadLong();			// 4
	float temp5 	= DataFlash.ReadLong();			// 5

	Serial.printf_P(PSTR("OF, %d, %d, %d, %4.7f, %4.7f\n"),
			temp1,
			temp2,
			temp3,
			temp4,
			temp5);
	#endif
}

static void Log_Write_Nav_Tuning()
{
	//Matrix3f tempmat = dcm.get_dcm_matrix();

	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_NAV_TUNING_MSG);

	DataFlash.WriteInt(wp_distance);						// 1
	DataFlash.WriteInt(target_bearing/100);					// 2
	DataFlash.WriteInt(long_error);							// 3
	DataFlash.WriteInt(lat_error);							// 4
	DataFlash.WriteInt(nav_lon);							// 5
	DataFlash.WriteInt(nav_lat);							// 6
	DataFlash.WriteInt(g.pi_nav_lon.get_integrator());		// 7
	DataFlash.WriteInt(g.pi_nav_lat.get_integrator());	    // 8
	//crosstrack_error
	//DataFlash.WriteInt(crosstrack_error);	// 9
	DataFlash.WriteInt(g.pi_loiter_lon.get_integrator());	// 9
	DataFlash.WriteInt(g.pi_loiter_lat.get_integrator());	// 10

	DataFlash.WriteByte(END_BYTE);
}


static void Log_Read_Nav_Tuning()
{
	int16_t temp;

	Serial.printf_P(PSTR("NTUN, "));

	for(int8_t i = 1; i < 10; i++ ){
		temp = DataFlash.ReadInt();
		Serial.printf("%d, ", temp);
	}

	temp = DataFlash.ReadInt();
	Serial.printf("%d\n", temp);
}


// Write a control tuning packet. Total length : 22 bytes
static void Log_Write_Control_Tuning()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_CONTROL_TUNING_MSG);

	DataFlash.WriteInt(g.rc_1.control_in);				// 0
	DataFlash.WriteInt(g.rc_2.control_in);				// 1
	DataFlash.WriteInt(g.rc_3.control_in);				// 2
	DataFlash.WriteInt(g.rc_4.control_in);				// 3
	DataFlash.WriteInt(sonar_alt);						// 4
	DataFlash.WriteInt(baro_alt);						// 5
	DataFlash.WriteInt(next_WP.alt);					// 6
	DataFlash.WriteInt(nav_throttle);					// 7
	DataFlash.WriteInt(angle_boost);					// 8
	DataFlash.WriteInt(manual_boost);					// 9
	DataFlash.WriteInt(climb_rate);						// 10
	DataFlash.WriteInt(g.rc_3.servo_out);				// 11
	DataFlash.WriteInt(g.pi_alt_hold.get_integrator());	// 12
	DataFlash.WriteInt(g.pi_throttle.get_integrator());	// 13

	DataFlash.WriteByte(END_BYTE);
}

// Read an control tuning packet
static void Log_Read_Control_Tuning()
{
	int16_t temp;

	Serial.printf_P(PSTR("CTUN, "));

	for(int8_t i = 0; i < 13; i++ ){
		temp = DataFlash.ReadInt();
		Serial.printf("%d, ", temp);
	}
	// read 13
	temp = DataFlash.ReadInt();
	Serial.printf("%d\n", temp);
}

// Write a performance monitoring packet. Total length : 19 bytes
static void Log_Write_Performance()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_PERFORMANCE_MSG);

	//DataFlash.WriteByte(	delta_ms_fast_loop);
	//DataFlash.WriteByte(	loop_step);



	DataFlash.WriteLong(	millis()- perf_mon_timer);			//1
	DataFlash.WriteByte(	dcm.gyro_sat_count);				//2
	DataFlash.WriteByte(	imu.adc_constraints);				//3
	DataFlash.WriteByte(	dcm.renorm_sqrt_count);				//4
	DataFlash.WriteByte(	dcm.renorm_blowup_count);			//5
	DataFlash.WriteByte(	gps_fix_count);						//6
	DataFlash.WriteByte(END_BYTE);


	//DataFlash.WriteInt (	(int)(dcm.get_health() * 1000));	//7



	// control_mode
	/*
	DataFlash.WriteByte(control_mode);					//1
	DataFlash.WriteByte(yaw_mode);						//2
	DataFlash.WriteByte(roll_pitch_mode);				//3
	DataFlash.WriteByte(throttle_mode);					//4
	DataFlash.WriteInt(g.throttle_cruise.get());		//5
	DataFlash.WriteLong(throttle_integrator);			//6
	DataFlash.WriteByte(END_BYTE);
	*/

}

// Read a performance packet
static void Log_Read_Performance()
{
	int32_t temp1 	= DataFlash.ReadLong();
	int8_t  temp2 	= DataFlash.ReadByte();
	int8_t  temp3 	= DataFlash.ReadByte();
	int8_t  temp4 	= DataFlash.ReadByte();
	int8_t 	temp5 	= DataFlash.ReadByte();
	int8_t	temp6 	= DataFlash.ReadByte();

							 //1   2   3   4   5   6
	Serial.printf_P(PSTR("PM, %ld, %d, %d, %d, %d, %d\n"),
		temp1,
		temp2,
		temp3,
		temp4,
		temp5,
		temp6);
}

// Write a command processing packet.
static void Log_Write_Cmd(byte num, struct Location *wp)
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_CMD_MSG);

	DataFlash.WriteByte(g.command_total);	// 1
	DataFlash.WriteByte(num);				// 2
	DataFlash.WriteByte(wp->id);			// 3
	DataFlash.WriteByte(wp->options);		// 4
	DataFlash.WriteByte(wp->p1);			// 5
	DataFlash.WriteLong(wp->alt);			// 6
	DataFlash.WriteLong(wp->lat);			// 7
	DataFlash.WriteLong(wp->lng);			// 8

	DataFlash.WriteByte(END_BYTE);
}
//CMD, 3, 0, 16, 8, 1, 800, 340440192, -1180692736


// Read a command processing packet
static void Log_Read_Cmd()
{
	int8_t temp1 	= DataFlash.ReadByte();
	int8_t temp2 	= DataFlash.ReadByte();
	int8_t temp3 	= DataFlash.ReadByte();
	int8_t temp4 	= DataFlash.ReadByte();
	int8_t temp5 	= DataFlash.ReadByte();
	long   temp6 	= DataFlash.ReadLong();
	long   temp7 	= DataFlash.ReadLong();
	long   temp8 	= DataFlash.ReadLong();

							//  1   2    3   4   5   6   7    8
	Serial.printf_P(PSTR( "CMD, %d, %d, %d, %d, %d, %ld, %ld, %ld\n"),
                    temp1,
                    temp2,
                    temp3,
                    temp4,
                    temp5,
                    temp6,
                    temp7,
                    temp8);
}

// Write an attitude packet. Total length : 10 bytes
static void Log_Write_Attitude()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_ATTITUDE_MSG);

	DataFlash.WriteInt((int)dcm.roll_sensor);		// 1
	DataFlash.WriteInt((int)dcm.pitch_sensor);		// 2
	DataFlash.WriteInt((uint16_t)dcm.yaw_sensor);	// 3

	DataFlash.WriteInt((int)g.rc_1.servo_out);		// 4
	DataFlash.WriteInt((int)g.rc_2.servo_out);		// 5
	DataFlash.WriteInt((int)g.rc_4.servo_out);		// 6

	DataFlash.WriteByte(END_BYTE);
}

// Read an attitude packet
static void Log_Read_Attitude()
{
	int16_t temp1 	= DataFlash.ReadInt();
	int16_t temp2 	= DataFlash.ReadInt();
	uint16_t temp3 	= DataFlash.ReadInt();
	int16_t temp4 	= DataFlash.ReadInt();
	int16_t temp5 	= DataFlash.ReadInt();
	int16_t temp6 	= DataFlash.ReadInt();

							// 1   2   3    4   5   6
	Serial.printf_P(PSTR("ATT, %d, %d, %u, %d, %d, %d\n"),
		temp1,
		temp2,
		temp3,
		temp4,
		temp5,
		temp6);
}

// Write a mode packet. Total length : 5 bytes
static void Log_Write_Mode(byte mode)
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_MODE_MSG);
	DataFlash.WriteByte(mode);
	DataFlash.WriteInt(g.throttle_cruise);
	DataFlash.WriteByte(END_BYTE);
}

// Read a mode packet
static void Log_Read_Mode()
{
	Serial.printf_P(PSTR("MOD:"));
	Serial.print(flight_mode_strings[DataFlash.ReadByte()]);
	Serial.printf_P(PSTR(", %d\n"),DataFlash.ReadInt());
}

static void Log_Write_Startup()
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_STARTUP_MSG);
	DataFlash.WriteByte(END_BYTE);
}

// Read a mode packet
static void Log_Read_Startup()
{
	Serial.printf_P(PSTR("START UP\n"));
}

static void Log_Write_Data(int8_t _type, float _data)
{
	Log_Write_Data(_type, (int32_t)(_data * 1000));
}

static void Log_Write_Data(int8_t _type, int32_t _data)
{
	DataFlash.WriteByte(HEAD_BYTE1);
	DataFlash.WriteByte(HEAD_BYTE2);
	DataFlash.WriteByte(LOG_DATA_MSG);
	DataFlash.WriteByte(_type);
	DataFlash.WriteLong(_data);
	DataFlash.WriteByte(END_BYTE);
}

// Read a mode packet
static void Log_Read_Data()
{
	int8_t  temp1 = DataFlash.ReadByte();
	int32_t temp2 = DataFlash.ReadLong();
	Serial.printf_P(PSTR("DATA: %d, %ld\n"), temp1, temp2);
}

// Read the DataFlash log memory
static void Log_Read(int start_page, int end_page)
{
	int packet_count = 0;

	#ifdef AIRFRAME_NAME
		Serial.printf_P(PSTR((AIRFRAME_NAME)
	#endif
	Serial.printf_P(PSTR("\n" THISFIRMWARE
						 "\nFree RAM: %u\n"),
                    memcheck_available_memory());

    if(start_page > end_page)
    {
    	packet_count = Log_Read_Process(start_page, DF_LAST_PAGE);
    	packet_count += Log_Read_Process(1, end_page);
    } else {
    	packet_count = Log_Read_Process(start_page, end_page);
    }

	//Serial.printf_P(PSTR("Number of packets read: %d\n"), packet_count);
}

// Read the DataFlash log memory : Packet Parser
static int Log_Read_Process(int start_page, int end_page)
{
	byte data;
	byte log_step 		= 0;
	int page 			= start_page;
	int packet_count = 0;

	DataFlash.StartRead(start_page);

	while (page < end_page && page != -1){

		data = DataFlash.ReadByte();

		// This is a state machine to read the packets
		switch(log_step){
			case 0:
				if(data == HEAD_BYTE1)	// Head byte 1
					log_step++;
				break;

			case 1:
				if(data == HEAD_BYTE2)	// Head byte 2
					log_step++;
				else{
					log_step = 0;
					Serial.println(".");
				}
				break;

			case 2:
				log_step = 0;
				switch(data){
					case LOG_ATTITUDE_MSG:
						Log_Read_Attitude();
						break;

					case LOG_MODE_MSG:
						Log_Read_Mode();
						break;

					case LOG_CONTROL_TUNING_MSG:
						Log_Read_Control_Tuning();
						break;

					case LOG_NAV_TUNING_MSG:
						Log_Read_Nav_Tuning();
						break;

					case LOG_PERFORMANCE_MSG:
						Log_Read_Performance();
						break;

					case LOG_RAW_MSG:
						Log_Read_Raw();
						break;

					case LOG_CMD_MSG:
						Log_Read_Cmd();
						break;

					case LOG_CURRENT_MSG:
						Log_Read_Current();
						break;

					case LOG_STARTUP_MSG:
						Log_Read_Startup();
						break;

					case LOG_MOTORS_MSG:
						Log_Read_Motors();
						break;

					case LOG_OPTFLOW_MSG:
						Log_Read_Optflow();
						break;

					case LOG_GPS_MSG:
						Log_Read_GPS();
						break;

					case LOG_DATA_MSG:
						Log_Read_Data();
						break;
				}
				break;
			case 3:
				if(data == END_BYTE){
					 packet_count++;
				}else{
					Serial.printf_P(PSTR("Error Reading END_BYTE: %d\n"),data);
				}
				log_step = 0;			// Restart sequence: new packet...
				break;
		}
		page = DataFlash.GetPage();
	}
	return packet_count;
}


#else // LOGGING_ENABLED

static void Log_Write_Startup() {}
static void Log_Read_Startup() {}
static void Log_Read(int start_page, int end_page) {}
static void Log_Write_Cmd(byte num, struct Location *wp) {}
static void Log_Write_Mode(byte mode) {}
static void start_new_log() {}
static void Log_Write_Raw() {}
static void Log_Write_GPS() {}
static void Log_Write_Current() {}
static void Log_Write_Attitude() {}
static void Log_Write_Data(int8_t _type, float _data){}
static void Log_Write_Data(int8_t _type, int32_t _data){}
static void Log_Write_Optflow() {}
static void Log_Write_Nav_Tuning() {}
static void Log_Write_Control_Tuning() {}
static void Log_Write_Motors() {}
static void Log_Write_Performance() {}
static int8_t process_logs(uint8_t argc, const Menu::arg *argv) { return 0; }

#endif // LOGGING_DISABLED
