/* Diagnostic program for NHRC (N1KDO) USB Radio Interface 
 *
 * Copyright (c) 2007-2011, Jim Dixon <jim@lambdatel.com>. All rights
 * reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 * 		 
 *
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <usb.h>
#include <termios.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <pthread.h>
#include <signal.h>
#include <alsa/asoundlib.h>

#ifdef __linux
#include <linux/soundcard.h>
#elif defined(__FreeBSD__)
#include <sys/soundcard.h>
#else
#include <soundcard.h>
#endif

#define C108_VENDOR_ID   0x0d8c
#define C108_PRODUCT_ID  0x000c 
#define C108A_PRODUCT_ID  0x013c

#define HID_REPORT_GET 0x01
#define HID_REPORT_SET 0x09

#define HID_RT_INPUT 0x01
#define HID_RT_OUTPUT 0x02

#define	AUDIO_BLOCKSIZE 4096
#define	AUDIO_SAMPLES_PER_BLOCK (AUDIO_BLOCKSIZE / 4)
#define	NFFT 1024
#define	NFFTSQRT 10

#define	AUDIO_IN_SETTING 800

#define MIXER_PARAM_MIC_PLAYBACK_SW "Mic Playback Switch"
#define MIXER_PARAM_MIC_PLAYBACK_VOL "Mic Playback Volume"
#define MIXER_PARAM_MIC_CAPTURE_SW "Mic Capture Switch"
#define MIXER_PARAM_MIC_CAPTURE_VOL "Mic Capture Volume"
#define MIXER_PARAM_MIC_BOOST "Auto Gain Control"
#define MIXER_PARAM_SPKR_PLAYBACK_SW "Speaker Playback Switch"
#define MIXER_PARAM_SPKR_PLAYBACK_VOL "Speaker Playback Volume"

#define EEPROM_START_ADDR       0
#define EEPROM_END_ADDR         63
#define EEPROM_PHYSICAL_LEN     64
#define EEPROM_TEST_ADDR        EEPROM_END_ADDR
#define EEPROM_MAGIC_ADDR       6
#define EEPROM_MAGIC            34329
#define EEPROM_CS_ADDR          62
#define EEPROM_RXMIXERSET       8
#define EEPROM_TXMIXASET        9
#define EEPROM_TXMIXBSET        10
#define EEPROM_RXVOICEADJ       11
#define EEPROM_RXCTCSSADJ       13
#define EEPROM_TXCTCSSADJ       15
#define EEPROM_RXSQUELCHADJ     16
#define EEPROM_CTL_ADDR         0
#define EEPROM_CTL              0x6700
#define EEPROM_VID_ADDR         1
#define EEPROM_PID_ADDR         2
#define	PID_N1KDO		0x6a00

#define PASSBAND_LEVEL		550.0
#define STOPBAND_LEVEL		117.0

#define	MAXUSBDEVICES 10

struct tonevars
{
float	mycr;
float	myci;
} ;

static struct usb_device *usbdevices[MAXUSBDEVICES];
char *usbdevstrs[MAXUSBDEVICES];
int usbport[MAXUSBDEVICES];
int usbordered[MAXUSBDEVICES];
int usbdevnums[MAXUSBDEVICES];
int usbdevtypes[MAXUSBDEVICES];
int nusbdevices = 0;
char usbunique[100];

enum {DEV_C108,DEV_C108AH,DEV_N1KDO};

char *devtypestrs[] = {"CM108","CM108AH","N1KDO-0","N1KDO-1","N1KDO-2","N1KDO-3",
	"N1KDO-4","N1KDO-5","N1KDO-6","N1KDO-7","N1KDO-8","N1KDO-9","N1KDO-10",
	"N1KDO-11","N1KDO-12","N1KDO-13","N1KDO-14","N1KDO-15"} ;

void cdft(int, int, double *, int *, double *);

float myfreq1[MAXUSBDEVICES],myfreq2[MAXUSBDEVICES],lev[MAXUSBDEVICES],lev1[MAXUSBDEVICES],lev2[MAXUSBDEVICES];

unsigned int frags = ( ( (6 * 5) << 16 ) | 0xc );

/* Call with:  devnum: alsa major device number, param: ascii Formal
Parameter Name, val1, first or only value, val2 second value, or 0 
if only 1 value. Values: 0-99 (percent) or 0-1 for baboon.

Note: must add -lasound to end of linkage */

int shutdown = 0;

static int amixer_max(int devnum,char *param)
{
int	rv,type;
char	str[100];
snd_hctl_t *hctl;
snd_ctl_elem_id_t *id;
snd_hctl_elem_t *elem;
snd_ctl_elem_info_t *info;

	sprintf(str,"hw:%d",devnum);
	if (snd_hctl_open(&hctl, str, 0)) return(-1);
	snd_hctl_load(hctl);
	snd_ctl_elem_id_alloca(&id);
	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, param);  
	elem = snd_hctl_find_elem(hctl, id);
	if (!elem)
	{
		snd_hctl_close(hctl);
		return(-1);
	}
	snd_ctl_elem_info_alloca(&info);
	snd_hctl_elem_info(elem,info);
	type = snd_ctl_elem_info_get_type(info);
	rv = 0;
	switch(type)
	{
	    case SND_CTL_ELEM_TYPE_INTEGER:
		rv = snd_ctl_elem_info_get_max(info);
		break;
	    case SND_CTL_ELEM_TYPE_BOOLEAN:
		rv = 1;
		break;
	}
	snd_hctl_close(hctl);
	return(rv);
}

/* Call with:  devnum: alsa major device number, param: ascii Formal
Parameter Name, val1, first or only value, val2 second value, or 0 
if only 1 value. Values: 0-99 (percent) or 0-1 for baboon.

Note: must add -lasound to end of linkage */

static int setamixer(int devnum,char *param, int v1, int v2)
{
int	type;
char	str[100];
snd_hctl_t *hctl;
snd_ctl_elem_id_t *id;
snd_ctl_elem_value_t *control;
snd_hctl_elem_t *elem;
snd_ctl_elem_info_t *info;

	sprintf(str,"hw:%d",devnum);
	if (snd_hctl_open(&hctl, str, 0)) return(-1);
	snd_hctl_load(hctl);
	snd_ctl_elem_id_alloca(&id);
	snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
	snd_ctl_elem_id_set_name(id, param);  
	elem = snd_hctl_find_elem(hctl, id);
	if (!elem)
	{
		snd_hctl_close(hctl);
		return(-1);
	}
	snd_ctl_elem_info_alloca(&info);
	snd_hctl_elem_info(elem,info);
	type = snd_ctl_elem_info_get_type(info);
	snd_ctl_elem_value_alloca(&control);
	snd_ctl_elem_value_set_id(control, id);    
	switch(type)
	{
	    case SND_CTL_ELEM_TYPE_INTEGER:
		snd_ctl_elem_value_set_integer(control, 0, v1);
		if (v2 > 0) snd_ctl_elem_value_set_integer(control, 1, v2);
		break;
	    case SND_CTL_ELEM_TYPE_BOOLEAN:
		snd_ctl_elem_value_set_integer(control, 0, (v1 != 0));
		break;
	}
	if (snd_hctl_elem_write(elem, control))
	{
		snd_hctl_close(hctl);
		return(-1);
	}
	snd_hctl_close(hctl);
	return(0);
}

static void set_outputs(struct usb_dev_handle *handle,
	     unsigned char *outputs)
{
	usleep(1500);
	usb_control_msg(handle,
	      USB_ENDPOINT_OUT + USB_TYPE_CLASS + USB_RECIP_INTERFACE,
	      HID_REPORT_SET,
	      0 + (HID_RT_OUTPUT << 8),
	      3,
	      (char*)outputs, 4, 5000);
}

static void setout(struct usb_dev_handle *usb_handle,unsigned char c)
{
unsigned char buf[4];

	buf[0] = buf[3] = 0;
	buf[2] = 0xd; /* set GPIO 1,3,4 as output */
	buf[1] = c; /* set GPIO 1,3,4 outputs appropriately */
	set_outputs(usb_handle,buf);
	usleep(100000);
}

static void get_inputs(struct usb_dev_handle *handle,
	     unsigned char *inputs)
{
	usleep(1500);
	usb_control_msg(handle,
	      USB_ENDPOINT_IN + USB_TYPE_CLASS + USB_RECIP_INTERFACE,
	      HID_REPORT_GET,
	      0 + (HID_RT_INPUT << 8),
	      3,
	      (char*)inputs, 4, 5000);
}

unsigned char getin(struct usb_dev_handle *usb_handle, int devtype)
{
unsigned char buf[4];
unsigned short c;

	buf[0] = buf[1] = 0;
	get_inputs(usb_handle,buf);
	c = buf[1] & 0xf;
	c += (buf[0] & 3) << 4;
	/* in the AN part, the HOOK comes in on buf[0] bit 4, undocumentedly */
	if (devtype != DEV_C108)
	{
		c &= 0xfd;
		if (!(buf[0] & 0x10)) c += 2;
	}
	return(c);
}

static unsigned short read_eeprom(struct usb_dev_handle *usb_handle, int addr)
{
    unsigned char buf[4];

    buf[0] = 0x80;
    buf[1] = 0;
    buf[2] = 0;
    buf[3] = 0x80 | (addr & 0x3f);
    set_outputs(usb_handle,buf);
    memset(buf,0,sizeof(buf));
    get_inputs(usb_handle,buf);
    return(buf[1] + (buf[2] << 8));
}


static unsigned short get_eeprom(struct usb_dev_handle *handle,
        unsigned short *buf)
{
int     i;
unsigned short cs;

        cs = 0xffff;
        for(i = EEPROM_START_ADDR; i < EEPROM_END_ADDR; i++)
        {
                cs += buf[i] = read_eeprom(handle,i);
        }
        return(cs);
}

static void write_eeprom(struct usb_dev_handle *usb_handle, int addr, unsigned short data)
{
    unsigned char buf[4];

    buf[0] = 0x80;
    buf[1] = data & 0xff;
    buf[2] = data >> 8;
    buf[3] = 0xc0 | (addr & 0x3f);
    set_outputs(usb_handle,buf);
}

static void put_eeprom(struct usb_dev_handle *handle,unsigned short *buf)
{
int     i;
unsigned short cs;

        cs = 0xffff;
        for(i = EEPROM_START_ADDR; i < EEPROM_CS_ADDR; i++)
        {
                write_eeprom(handle,i,buf[i]);
                cs += buf[i];
        }
        buf[EEPROM_CS_ADDR] = (65535 - cs) + 1;
        write_eeprom(handle,i,buf[EEPROM_CS_ADDR]);
}


static struct usb_device *device_init_one(char **strp,int *devnum, int *devtype)
{
	struct usb_bus *usb_bus;
	struct usb_device *dev;
	char devstr[200],str[200],desdev[200],*cp;
	int i,j;
	FILE *fp;

	for (usb_bus = usb_busses;
	     usb_bus;
	     usb_bus = usb_bus->next) {
	    for (dev = usb_bus->devices;
	         dev;
	         dev = dev->next) {
	        if ((dev->descriptor.idVendor
	              == C108_VENDOR_ID) &&
	            ((dev->descriptor.idProduct
	              == C108_PRODUCT_ID) ||
	            (dev->descriptor.idProduct
	              == C108A_PRODUCT_ID) ||
	            ((dev->descriptor.idProduct & 0xff00)
	              == PID_N1KDO)))
		{
	                    sprintf(devstr,"%s/%s", usb_bus->dirname,dev->filename);
			for(i = 0; i < 32; i++)
			{
				sprintf(str,"/proc/asound/card%d/usbbus",i);
				fp = fopen(str,"r");
				if (!fp) continue;
				if ((!fgets(desdev,sizeof(desdev) - 1,fp)) || (!desdev[0]))
				{
					fclose(fp);
					continue;
				}
				fclose(fp);
				if (desdev[strlen(desdev) - 1] == '\n')
			        	desdev[strlen(desdev) -1 ] = 0;
				if (strcasecmp(desdev,devstr)) continue;
				if (i) sprintf(str,"/sys/class/sound/dsp%d/device",i);
				else strcpy(str,"/sys/class/sound/dsp/device");
				memset(desdev,0,sizeof(desdev));
				if (readlink(str,desdev,sizeof(desdev) - 1) == -1) {
				        sprintf(str,"/sys/class/sound/controlC%d/device",i);
				        memset(desdev,0,sizeof(desdev));
				        if (readlink(str,desdev,sizeof(desdev) - 1) == -1) continue;
				}
				cp = strrchr(desdev,'/');
				if (cp) *cp = 0; else continue;
				cp = strrchr(desdev,'/');
				if (!cp) continue;
				cp++;
				break;
			}
			if (i >= 32) continue;
			for(j = 0; j < nusbdevices; j++)
				if (usbdevices[j] == dev) break;
			if (j < nusbdevices) continue;
			j = DEV_C108;
			if (dev->descriptor.idProduct
			    == C108A_PRODUCT_ID) j = DEV_C108AH;
			if ((dev->descriptor.idProduct & 0xff00) ==
				PID_N1KDO) j = DEV_N1KDO | 
					(dev->descriptor.idProduct & 0xf);
			if (devnum) *devnum = i;
			if (devtype) *devtype = j;
			printf("Found %s USB Radio Interface at %s\n",
				devtypestrs[j],cp);
			if (strp) *strp = strdup(cp);
			return dev;
		}
	    }
	}
	return NULL;
}

static void device_init(void)
{
int i,j,k,maxport,lastport;
char *cp;
static struct usb_device *p;
	
	usb_init();
	usb_find_busses();
	usb_find_devices();
	usbdevices[0] = NULL;
	usbunique[0] = 0;
	while(nusbdevices < MAXUSBDEVICES)
	{
		p = device_init_one(&usbdevstrs[nusbdevices],
			&usbdevnums[nusbdevices],&usbdevtypes[nusbdevices]);
		if (!p) break;
		usbdevices[nusbdevices++] = p;
	}
	for(i = 0; i < nusbdevices; i++)
	{
		for(j = 0,cp = usbdevstrs[i]; cp[j]; j++)
		{
			if ((j < strlen(usbunique)) &&
				(usbunique[j] != cp[j])) break;
			usbunique[j] = cp[j];
		}
		usbunique[j] = 0;
	}
	maxport = 0;
	for(i = 0; i < nusbdevices; i++)
	{
		usbport[i] = atoi(usbdevstrs[i] + strlen(usbunique));
		if (usbport[i] > maxport) maxport = usbport[i];
	}
	lastport = -1;
	for(i = 0; i < nusbdevices; i++)
	{
		for(j = lastport + 1; j <= maxport; j++)
		{
			for(k = 0; k < nusbdevices; k++)
			{
				if (usbport[k] == j) break;
			}
			if (k >= nusbdevices) continue;
			usbordered[i] = k;
			lastport = j;
			break;
		}
		printf("Device %d:  USB PORT %d \n",i,usbport[usbordered[i]]);
	}


	return;
}

static inline char *baboons(int v)
{
	if (v) return "1";
	return "0";
}

static int dioerror(unsigned char got, unsigned char should)
{
unsigned char err = got ^ should;
int	n = 0;

	if (err & 0x10) {
		printf("Error on GPIO3/PTT/CAS IN, got %s, should be %s\n",
			baboons(got & 0x10),baboons(should & 0x10));
		n++;
		}
	if (err & 0x20) {
		printf("Error on GPIO3/PTT/CTCSS IN, got %s, should be %s\n",
			baboons(got & 0x20),baboons(should & 0x20));
		n++;
		}
	return(n);
}

static int testio(struct usb_dev_handle *usb_handle,int devtype,unsigned char toout,
	unsigned char toexpect)
{
unsigned char c;

	setout(usb_handle,toout);  /* should readback 0 */
	c = getin(usb_handle,devtype) & 0xf2;
	return(dioerror(c,toexpect));
}

static float get_tonesample(struct tonevars *tvars,float ddr,float ddi,int devtype)
{

	float t;
	
	t =tvars->mycr*ddr-tvars->myci*ddi;
	tvars->myci=tvars->mycr*ddi+tvars->myci*ddr;
	tvars->mycr=t;
	
	t=2.0-(tvars->mycr*tvars->mycr+tvars->myci*tvars->myci);
	tvars->mycr*=t;
	tvars->myci*=t;
	if (devtype != DEV_C108) return tvars->mycr;
	return tvars->mycr * 0.9092;
}

static int outaudio(int fd,int devtype,float freq1, float freq2)
{
unsigned short buf[AUDIO_SAMPLES_PER_BLOCK * 2];
float	f,ddr1,ddi1,ddr2,ddi2;
int	i;
static struct tonevars t1,t2;

	if (freq1 > 0.0)
	{
		ddr1 = cos(freq1*2.0*M_PI/48000.0);
		ddi1 = sin(freq1*2.0*M_PI/48000.0);
	} else {
		t1.mycr = 1.0;
		t1.myci = 0.0;
	}
		
	if (freq2 > 0.0)
	{
		ddr2 = cos(freq2*2.0*M_PI/48000.0);
		ddi2 = sin(freq2*2.0*M_PI/48000.0);
	} else {
		t2.mycr = 1.0;
		t2.myci = 0.0;
	}
	for(i = 0; i < AUDIO_SAMPLES_PER_BLOCK * 2; i += 2)
	{
		if (freq1 > 0.0)
		{
			f = get_tonesample(&t1,ddr1,ddi1,devtype);
			buf[i] = f * 32765;
		} else buf[i] = 0;
		if (freq2 > 0.0)
		{
			f = get_tonesample(&t2,ddr2,ddi2,devtype);
			buf[i + 1] = f * 32765;
		} else buf[i + 1] = 0;
	}
	if (write(fd,buf,AUDIO_BLOCKSIZE) != AUDIO_BLOCKSIZE) return(-1);
	return 0;
}

static int soundopen(int devicenum)
{
int	fd,res,fmt,desired;
char	device[200];

	   strcpy(device,"/dev/dsp");
	   if (devicenum)
	            sprintf(device,"/dev/dsp%d",devicenum);
	   fd = open(device, O_RDWR | O_NONBLOCK);
	   if (fd < 0) {
	           printf("Unable to open DSP device %d: %s\n", devicenum,device);
	           return -1;
	   }
#if __BYTE_ORDER == __LITTLE_ENDIAN
	    fmt = AFMT_S16_LE;
#else
	    fmt = AFMT_S16_BE;
#endif
	    res = ioctl(fd, SNDCTL_DSP_SETFMT, &fmt);
	    if (res < 0) {
	            printf("Unable to set format to 16-bit signed\n");
	            return -1;
	    }
	    res = ioctl(fd, SNDCTL_DSP_SETDUPLEX, 0);
	    /* Check to see if duplex set (FreeBSD Bug) */
	    res = ioctl(fd, SNDCTL_DSP_GETCAPS, &fmt);
	    if ((res != 0) || (!(fmt & DSP_CAP_DUPLEX))) {
	            printf("Doesnt have full duplex mode\n");
	            return -1;
	    }
	    fmt = 1;
	    res = ioctl(fd, SNDCTL_DSP_STEREO, &fmt);
	    if (res < 0) {
	            printf("Failed to set audio device to mono\n");
	            return -1;
	    }
	    fmt = desired = 48000;
	    res = ioctl(fd, SNDCTL_DSP_SPEED, &fmt);
	    if (res < 0) {
	            printf("Failed to set audio device to 48k\n");
	            return -1;
	    }
	    if (fmt != desired) {
	            printf("Requested %d Hz, got %d Hz -- sound may be choppy\n",
	                 desired, fmt);
	    }

	   /*
	     * on Freebsd, SETFRAGMENT does not work very well on some cards.
	     * Default to use 256 bytes, let the user override
	     */
	    if (frags) {
	            fmt = frags;
	            res = ioctl(fd, SNDCTL_DSP_SETFRAGMENT, &fmt);
	            if (res < 0) {
	                     printf("Unable to set fragment size -- sound may be choppy\n");
	            }
	    }
	    /* on some cards, we need SNDCTL_DSP_SETTRIGGER to start outputting */
	    res = PCM_ENABLE_INPUT | PCM_ENABLE_OUTPUT;
	    res = ioctl(fd, SNDCTL_DSP_SETTRIGGER, &res);
	    /* it may fail if we are in half duplex, never mind */
	    return fd;
}

void *soundthread(void *this)
{
int fd,micmax,spkrmax,index = (int)this;
int devnum = usbdevnums[index];

	fd = soundopen(devnum);
	micmax = amixer_max(devnum,MIXER_PARAM_MIC_CAPTURE_VOL);
	spkrmax = amixer_max(devnum,MIXER_PARAM_SPKR_PLAYBACK_VOL);

	setamixer(devnum,MIXER_PARAM_MIC_PLAYBACK_SW,0,0);
	setamixer(devnum,MIXER_PARAM_MIC_PLAYBACK_VOL,0,0);
	setamixer(devnum,MIXER_PARAM_SPKR_PLAYBACK_SW,1,0);
	setamixer(devnum,MIXER_PARAM_SPKR_PLAYBACK_VOL,spkrmax,spkrmax);
	setamixer(devnum,MIXER_PARAM_MIC_CAPTURE_VOL,
			AUDIO_IN_SETTING * micmax / 1000,0);
	setamixer(devnum,MIXER_PARAM_MIC_BOOST,0,0);
	setamixer(devnum,MIXER_PARAM_MIC_CAPTURE_SW,1,0);

	myfreq1[index] = myfreq2[index] = lev[index] = lev1[index] = lev2[index] = 0.0;

	while(!shutdown)
	{
		fd_set rfds,wfds;
		int res;
		char buf[AUDIO_BLOCKSIZE];
		float mylev,mylev1,mylev2;

		FD_ZERO(&rfds);
		FD_ZERO(&wfds);
		FD_SET(fd,&rfds);
		FD_SET(fd,&wfds);
		res = select(fd + 1,&rfds,&wfds,NULL,NULL);
		if (!res) continue;
		if (res < 0)
		{
			perror("poll");
			exit(255);
		}
		if (FD_ISSET(fd,&wfds))
		{
			outaudio(fd,usbdevtypes[index],myfreq1[index],myfreq2[index]);
			continue;
		}
		if (FD_ISSET(fd,&rfds))
		{
			short *sbuf = (short *) buf;
			static double afft[(NFFT + 1) * 2 + 1],wfft[NFFT * 5 / 2];
			float buck;
			float gfac;
			static int ipfft[NFFTSQRT + 2],i;

			res = read(fd,buf,AUDIO_BLOCKSIZE);
			if (res < AUDIO_BLOCKSIZE) {
				printf("Warining, short read!!\n");
				continue;
			}
			memset(afft,0,sizeof(double) * 2 * (NFFT + 1));
			gfac = 1.0;
			if (usbdevtypes[index] != DEV_C108) gfac = 0.7499;
			for(i = 0; i < res / 2; i++)
			{
				sbuf[i] = (int) (((float)sbuf[i] + 32768) * gfac) - 32768;

			}
			for(i = 0; i < NFFT * 2; i += 2)
			{
				afft[i] = (double)(sbuf[i] + 32768) / (double)65536.0;
			}
			ipfft[0] = 0;
			cdft(NFFT * 2,-1,afft,ipfft,wfft);
			mylev = 0.0;
			mylev1 = 0.0;
			mylev2 = 0.0;
			for(i = 1; i < NFFT / 2; i++)
			{
				float ftmp;

				ftmp = (afft[i * 2] * afft[i * 2]) + 
				    (afft[i * 2 + 1] * afft[i * 2 + 1]);

				mylev += ftmp;
				buck = (float) i * 46.875;
				if (myfreq1[index] > 0.0)
				{
					if (fabs(buck - myfreq1[index]) < 1.5 * 46.875) mylev1 += ftmp;
				}
				if (myfreq2[index] > 0.0)
				{		
					if (fabs(buck - myfreq2[index]) < 1.5 * 46.875) mylev2 += ftmp;
				}
			}
			lev[index] = (sqrt(mylev) / (float) (NFFT / 2)) * 4096.0;
			lev1[index] = (sqrt(mylev1) / (float) (NFFT / 2)) * 4096.0;
			lev2[index] = (sqrt(mylev2) / (float) (NFFT / 2)) * 4096.0;
		}
	}
	close(fd);
	pthread_exit(NULL);
}

static int digital_test(struct usb_dev_handle *usb_handle,int devtype)
{
int	nerror = 0;

	printf("Testing digital I/O (PTT,COR,TONE and GPIO)....\n");
	nerror += testio(usb_handle,devtype,8,0); /* NONE */
	nerror += testio(usb_handle,devtype,0xc,0x30); /* GPIO3/PTT -> CAS/CTCSS */
	nerror += testio(usb_handle,devtype,8,0); /* NONE */
	if (!nerror) printf("Digital I/O passed!!\n");
	else printf("Digital I/O had %d errors!!\n",nerror);
	return(nerror);
}

static int analog_test_one(int index,float freq1,float freq2,float dlev1, float dlev2,int v)
{
	int nerror = 0;
	myfreq1[index] = freq1;
	myfreq2[index] = freq2;
	printf("Testing Analog at %1.f (and %1.f) Hz...\n",freq1,freq2);
	usleep(1000000);
	if (fabs(lev1[index] - dlev1) > (dlev1 * 0.2))
	{
		printf("Analog level on left channel for %.1f Hz (%.1f) is out of range!!\n",freq1,lev1[index]);
		printf("Must be between %.1f and %.1f\n",dlev1 * .8, dlev1 * 1.2);
		nerror++;
	} else if (v) printf("Left channel level %.1f OK at %.1f Hz\n",lev1[index],freq1);
	if (fabs(lev2[index] - dlev2) > (dlev2 * 0.2))
	{
		printf("Analog level on right channel for %.1f Hz (%.1f) is out of range!!\n",freq2,lev2[index]);
		printf("Must be between %.1f and %.1f\n",dlev2 * .8, dlev2 * 1.2);
		nerror++;
	} else if (v) printf("Right channel level %.1f OK at %.1f Hz\n",lev2[index],freq2);
	return(nerror);
}

static int analog_test(int index,int v)
{
int	nerror = 0;

	nerror += analog_test_one(index,204.0,700.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,504.0,700.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,1004.0,700.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,2004.0,700.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,3004.0,700.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,5004.0,700.0,STOPBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,204.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,504.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,1004.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,2004.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,3004.0,PASSBAND_LEVEL,PASSBAND_LEVEL,v);
	nerror += analog_test_one(index,700.0,5004.0,PASSBAND_LEVEL,STOPBAND_LEVEL,v);
	if (!nerror) printf("Analog Test Passed!!\n");
	return(nerror);
}

static int eeprom_test(struct usb_dev_handle *usb_handle)
{
unsigned short sbuf[64];
int	i,nerror = 0;

	i = get_eeprom(usb_handle,sbuf);
	if (i)
	{
		printf("Failure!! EEPROM fail checksum or not present\n");
		nerror++;
	}
	write_eeprom(usb_handle,EEPROM_TEST_ADDR,0x6942);
	i = read_eeprom(usb_handle,EEPROM_TEST_ADDR);
	if (i != 0x6942)
	{
		printf("Error!! EEPROM wrote 6942 hex, read %04x hex\n",i);
		nerror++;
	}
	return(nerror);
}

static int eeprom_list(struct usb_dev_handle *usb_handle,int index)
{
unsigned short sbuf[64];
int	i,nerror = 0;
float	f;

	i = get_eeprom(usb_handle,sbuf);
	if (i)
	{
		printf("Failure!! EEPROM fail checksum or not present\n");
		nerror++;
	}
	if ((sbuf[EEPROM_PID_ADDR] & 0xff00) != PID_N1KDO)
	{
		printf("Error!! EEPROM PID not N1KDO type, got %04x hex, expected %04x hex\n",
			sbuf[EEPROM_PID_ADDR],PID_N1KDO);
		nerror++;
	}
	else printf("Found N1KDO port number: %i\n",sbuf[EEPROM_PID_ADDR] & 0xff);
	if (sbuf[EEPROM_MAGIC_ADDR] != EEPROM_MAGIC)
	{
		printf("Error!! EEPROM MAGIC BAD, got %04x hex, expected %04x hex\n",
			sbuf[EEPROM_MAGIC_ADDR],EEPROM_MAGIC);
		nerror++;
	}
	if (nerror) return(nerror);
        printf("rxmixerset=%i\n",sbuf[EEPROM_RXMIXERSET]);
        printf("txmixaset=%i\n",sbuf[EEPROM_TXMIXASET]);
        printf("txmixbset=%i\n",sbuf[EEPROM_TXMIXBSET]);
	memcpy(&f,&sbuf[EEPROM_RXVOICEADJ],sizeof(float));
        printf("rxvoiceadj=%f\n",f);
	memcpy(&f,&sbuf[EEPROM_RXCTCSSADJ],sizeof(float));
        printf("rxctcssadj=%f\n",f);
        printf("txctcssadj=%i\n",sbuf[EEPROM_TXCTCSSADJ]);
        printf("rxsquelchadj=%i\n",sbuf[EEPROM_RXSQUELCHADJ]);
	return(0);
}

static void eeprom_init(struct usb_dev_handle *usb_handle,int index)
{
unsigned short sbuf[64];

	memset(sbuf,0xff,sizeof(sbuf));
	sbuf[EEPROM_CTL_ADDR] = EEPROM_CTL;
	sbuf[EEPROM_VID_ADDR] = C108_VENDOR_ID;
	sbuf[EEPROM_PID_ADDR] = 0x6a00 | index;
	put_eeprom(usb_handle,sbuf);
}

int main(int argc, char **argv)
{
struct usb_device *usb_dev;
struct usb_dev_handle *usb_handle,*usb_handles[MAXUSBDEVICES];
int retval = 1,curport,i;
char c;
pthread_t sthread[MAXUSBDEVICES];
pthread_attr_t attr;
struct termios t,t0;
float myfreq;

	printf("N1KDODiag, diagnostic program for the N1KDO\n");
	printf("USB Radio Interface, version 0.4, 01/10/11\n\n");

	device_init();
	if (!nusbdevices) {
		fprintf(stderr, "USB Device(s) not found\n");
		exit(255);
	}
	for(i = 0; i < nusbdevices; i++)
	{
		usb_handles[i] = usb_open(usbdevices[i]);
		if (usb_handles[i] == NULL) {
			fprintf(stderr,"Not able to open USB device\n");
			goto exit;
		}
		if (usb_claim_interface(usb_handles[i],3) < 0)
		{
			if (usb_detach_kernel_driver_np(usb_handles[i],3) < 0) {
				goto exit;
			}
			if (usb_claim_interface(usb_handles[i],3) < 0) {
				goto exit;
			}
		}
		setout(usb_handles[i],8);
	}
	for(i = 0; i < nusbdevices; i++)
	{
		pthread_attr_init(&attr);
		pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
		pthread_create(&sthread[i],&attr,soundthread,(void *)i);
	}
	usleep(500000);

	curport = usbordered[0];
	tcgetattr(fileno(stdin),&t0);
	for(;;)
	{
		char str[80];
		int errs = 0;

		usb_dev = usbdevices[curport];
		usb_handle = usb_handles[curport];
		tcsetattr(fileno(stdin),TCSANOW,&t0);
		myfreq = 0.0;
		myfreq1[curport] = 0.0;
		myfreq2[curport] = 0.0;
		printf("\nCurrent USB device:  %d (Port %d)\n\n",usbordered[curport],usbport[curport]);
		printf("Menu:\r\n\n");
		if (nusbdevices > 1)
		{
			printf("USB Device Selection:\n");
			printf("0 thru %d - Select specified USB Device\n",nusbdevices - 1);
		}
		printf("For Left Channel:\n");
		printf("11 - 1004Hz, 12 - 204Hz, 13 - 300Hz, 14 - 404Hz, 15 - 502Hz\n");
		printf("16 - 1502Hz, 17 - 2004Hz, 18 - 3004Hz, 19 - 5004Hz\n");
		printf("For Right Channel:\n");
		printf("11 - 1004Hz, 22 - 204Hz, 23 - 300Hz, 24 - 404Hz, 25 - 502Hz\n");
		printf("26 - 1502Hz, 27 - 2004Hz, 28 - 3004Hz, 29 - 5004Hz\n");
		printf("Tests, etc.\n");
		printf("t - test normal operation (use uppercase 'T' for verbose output)\n");
		printf("i - test digital signals only (CAS,CTCSS Decode,PTT)\n");
		printf("e - test EEPROM, E - Initialize ALL EEPROM(s)\n");
		printf("l - list EEPROM contents\n");
		printf("c - show test (loopback) connector pinout\n");
		printf("q,x - exit program\r\n\n");
		printf("Enter your selection:");
		fflush(stdout);
		fgets(str,sizeof(str) - 1,stdin);
		if ((strlen(str) == 2) && (isdigit(*str)))
		{
			i = atoi(str);
			if (i < nusbdevices)
			{
				curport = usbordered[i];
				printf("\nCurrent USB device changed to:  %d (Port %d)\n\n",usbordered[curport],usbport[curport]);
			}
			continue;
		}
		c = str[0];
		if (isupper(c)) c = tolower(str[0]);
		switch (c)
		{
		    case 'x':
		    case 'q':
			goto exit;
		    case '1': 
			myfreq = 1004.0;
			break;
		    case '2': 
			myfreq = 204.0;
			break;
		    case '3': 
			myfreq = 300.0;
			break;
		    case '4': 
			myfreq = 404.0;
			break;
		    case '5': 
			myfreq = 502.0;
			break;
		    case '6': 
			myfreq = 1502.0;
			break;
		    case '7': 
			myfreq = 2004.0;
			break;
		    case '8': 
			myfreq = 3004.0;
			break;
		    case '9': 
			myfreq = 5004.0;
			break;
		    case 0:
		    case '\n' :
		    case '\r' :
			myfreq = 0;
			break;
		    case 'i':
			digital_test(usb_handle,usbdevtypes[curport]);
			continue;
		    case 't':
		    case 'T':
			errs = digital_test(usb_handle,usbdevtypes[curport]);
			errs += analog_test(curport,str[0] == 'T');
			if (!errs) printf("System Tests all Passed successfully!!!!\n");
			else printf("%d Error(s) found during test(s)!!!!\n",errs);
			printf("\n\n");
			continue;
		    case 'E':
		    case 'e':
			if (str[0] == 'E')
			{
				for(i = 0; i < nusbdevices; i++)
				{
					eeprom_init(usb_handles[usbordered[i]],i);
				}
				printf("\nEEPROM(s) Initialized\n\n");
				continue;
			}
			printf("\n\n");
			errs = eeprom_test(usb_handle);
			if (!errs) printf("EEPROM test Passed successfully!!!!\n");
			else printf("%d Error(s) found during test(s)!!!!\n",errs);
			printf("\n\n");
			continue;
		    case 'l':
			printf("\n");
			errs = eeprom_list(usb_handle,usbordered[curport]);
			if (!errs) printf("EEPROM list successful!!!!\n");
			else printf("%d Error(s) found during operaton!!!!\n",errs);
			printf("\n");
			continue;
		    case 'c': /* show test cable pinout */
			printf("Special Test Cable Pinout:\n\n");
			printf("9 pin D-shell connector\n");
			printf("  Pin 2 to Pin 3 and 7\n");
			printf("  10K Resistor between Pins 4 & 5\n");
			printf("  10K Resistor between Pins 5 & 6\n\n");
			continue;
		    default:
			continue;
		}
		if ((strlen(str) > 1) && (str[1] == '2')) myfreq2[curport] = myfreq;
		else myfreq1[curport] = myfreq;
		tcgetattr(fileno(stdin),&t);
		cfmakeraw(&t);
		t.c_cc[VTIME] = 10;
		t.c_cc[VMIN] = 0;
		tcsetattr(fileno(stdin),TCSANOW,&t);
		for(;;)
		{
			int c = getc(stdin);
			if (c > 0) break;
			usleep(500000);
			printf("Level at %.1f Hz: %.1f mV (RMS) %.1f mV (P-P)\r\n",myfreq,lev[curport],lev[curport] * 2.828);
		}
	}
exit:
	shutdown = 1;
	for(i = 0; i < nusbdevices; i++)
		pthread_join(sthread[i],NULL);
	usb_close(usb_handle);
	return retval;
}


