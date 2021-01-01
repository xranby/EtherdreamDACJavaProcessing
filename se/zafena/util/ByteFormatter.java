package se.zafena.util;


import java.util.*; // required for use of BitSet


public class ByteFormatter  {

    public static BitSet reverseBitSet(final BitSet bits){
        final BitSet result = new BitSet(bits.length());

        for (int i=0; i<bits.length(); i++) {
            if (bits.get(i)) {
                result.set(bits.length()-i);
            }
        }

        return result;
    }

   public  static int IntFromBitSet(final BitSet bits) {
        int result = 0;
        for (int i=0; i<bits.length(); i++) {
            if (bits.get(i)) {
                result |= 1<<i;
            }
        }

      return result;
    }

    public  static byte[] BitSetToByteArray(final BitSet bits) {
        final byte[] bytes = new byte[bits.length()/8+1];
        for (int i=0; i<bits.length(); i++){
            if (bits.get(i)) {
                bytes[bytes.length-i/8-1] |= 1<<(i%8);
            }
        }
        return bytes;
    }


    public  static BitSet BitSetFromByteArray(final byte[] bytes){
        final BitSet bits = new BitSet();
        for (int i=0; i<(bytes.length*8); i++){
            if((bytes[bytes.length-i/8-1]&(1<<(i%8)))>0) {
                bits.set(i);
            }
        }
        return bits;
    }

    public  static byte[] AddDataToBeginningOfData(final byte[] start,final byte[] end) {

        if(end.length==0){
            return start;
        }

        if(start.length==0){
            return end;
        }

        final byte[] result = new byte[start.length+end.length];

        int i;
        for(i=0;i<start.length;i++){
            result[i]=start[i];
        }

        for(i=0;i<end.length;i++){
            result[start.length+i]=end[i];
        }

        return result;
    }

    public  static byte[] RemoveBytesFromBeginning(final byte[] data,final int remove) {

        if(data.length>remove){
           final byte[] result = new byte[data.length-remove];
           int i;
           for(i=0;i<data.length-remove;i++){
               result[i]=data[i+remove];
           }

           return result;
        } else {
           return new byte[0];
        }
    }

    /**
     * Convert a byte[] array to readable string format.
     * This makes the "hex" readable!
     * @return result String buffer in String format
     * @param in byte[] buffer to convert to string format
     */
    public  static String byteArrayToHexString(final byte in[]) {
        final char[] hexChars = new char[in.length * 2];
        for (int j = 0; j < in.length; j++) {
            final int v = in[j] & 0xFF;
            hexChars[j * 2] = HEX_ARRAY[v >>> 4];
            hexChars[j * 2 + 1] = HEX_ARRAY[v & 0x0F];
        }
        return new String(hexChars);
    }
    private static final char[] HEX_ARRAY = "0123456789ABCDEF".toCharArray();

    /** low level function to go from float to bytes */
    public  static byte[] floatToByteArray(final float value)
    {
        final byte[] result = new byte[4];

        final int intBits=Float.floatToIntBits(value);
        result[0]=(byte)((intBits&0x000000ff));
        result[1]=(byte)((intBits&0x0000ff00)>>8);
        result[2]=(byte)((intBits&0x00ff0000)>>16);
        result[3]=(byte)((intBits&0xff000000)>>24);

        return result;
    }

    public  static byte[] reverseByteArray(final byte[] data){
        final int length = data.length;
        final byte[] result = new byte[length];
        int i;

        for (i=0;i<data.length;i++)
        {
            result[i]=data[length-1-i];
        }

        return result;
    }

    public  static byte[] getFirstBytes(final byte[] data, final int length) {


        final byte[] result = new byte[length];

        int i;

        int readlength;

        if(length<data.length){
            readlength=length;
        } else {
            readlength=data.length;
        }


        for (i=0;i<readlength;i++)
        {
            result[i]=data[i];
        }

        return result;
    }

    public  static byte[] getLastBytes(final byte[] data, final int length) {
        final int dataLength = data.length;
        final byte[] result = new byte[length];

        int i;
        int readLength;

        if(length<dataLength){
            readLength=length;
        } else {
            readLength=dataLength;
        }

        for (i=0;i<readLength;i++)
        {
            if((dataLength-length+i)>=0)
            {
                result[i]=data[dataLength-length+i];
            }
        }

        return result;
    }

    public  static byte[] getSubBytes(final byte[] data, final int start,final int length) {


        final byte[] result = new byte[length];

        int i;

        int readlength;

        if((start+length)<data.length){
            readlength=length;
        } else {
            readlength=data.length-start;
        }


        for (i=0;i<readlength;i++)
        {
            result[i]=data[i+start];
        }

        return result;
    }



    public  static byte[] HexStringToByteArray(String s) {

        if(s.startsWith("0x")) {
            s = s.substring(2);
        }

        final byte[] b = new byte[s.length() / 2];
        for (int i = 0; i < b.length; i++){
        final int index = i * 2;
        final int v = Integer.parseInt(s.substring(index, index + 2), 16);
        b[i] = (byte)v;
        }
        return b;

    }

   public  static char[] byteArrayToCharArray(final byte[] data) {


        final char[] result = new char[data.length];

        int i;


        for (i=0;i<data.length;i++)
        {
            result[i]=(char)data[i];
        }

        return result;
    }

      public  static byte[] charArrayToByteArray(final char[] data) {


        final byte[] result = new byte[data.length];

        int i;


        for (i=0;i<data.length;i++)
        {
            result[i]=(byte)data[i];
        }

        return result;
    }

    public static byte[] removeAllBeginning(final byte[] buffer,final byte b) {
        if(buffer.length>=1){
            if(buffer[0]!=b){
                //do nothing.
                return buffer;
            } else {
                int i=0;
                while(buffer[i]==b&&i+1<buffer.length){
                    i++;
                }

                return getSubBytes(buffer,i,buffer.length);

            }
        } else {
            //do nothing.
            return buffer;
        }
    }

    public static byte[] removeAllLowASCII(final byte[] buffer, final int maxAscii) {

        if(buffer.length>0){
            int i=0;
            int j=0;
            while(i<buffer.length){

               if(buffer[i]>maxAscii){
                   j++;
               }
               i++;
            }
            final byte[] newBuffer = new byte[j];

            i=0;
            j=0;
            while(i<buffer.length){

               if(buffer[i]>maxAscii){
                   newBuffer[j]=buffer[i];
                   j++;
               }
               i++;
            }

            return newBuffer;

        } else {
            return buffer;
        }
    }

    public static byte[] replaceBytesWithBytes(final byte[] buffer,final byte[] b5, final byte[] u) {
        final String find = ByteFormatter.byteArrayToHexString(b5);
        final String replace = ByteFormatter.byteArrayToHexString(u);

        final String hexbuffer = ByteFormatter.byteArrayToHexString(buffer);

        final String result = hexbuffer.replaceAll(find, replace);

        return ByteFormatter.HexStringToByteArray(result);
    }

    public static byte[] safeASCII(final byte[] buffer) {
        if(buffer.length>0){
            // calculate length of new buffer
            int i=0;
            int j=0;
            while(i<buffer.length){
               if(buffer[i]>=0x20 /* lower ascii up to space is unsafe */ && buffer[i]<0x7F /* del and high ascii is unsafe*/){
                   j++;
               }
               i++;
            }
            // create new buffer
            final byte[] newBuffer = new byte[j];

            // fill and return new buffer containtin safe ascii
            i=0;
            j=0;
            while(i<buffer.length){

               if(buffer[i]>=0x20 /* lower ascii up to space is unsafe */ && buffer[i]<0x7F /* del and high ascii is unsafe*/){
                   newBuffer[j]=buffer[i];
                   j++;
               }
               i++;
            }

            return newBuffer;

        } else {
            return buffer;
        }
    }

    public static String bitSetToString(final BitSet bits) {
        String result = "";
        for (int i=0; i<bits.length(); i++) {
            if (bits.get(i)) {
                result+="1";
            } else {
                result+="0";
            }
        }

        return result;
    }

    public static String stringToHexString(final String string) {
        return byteArrayToHexString(string.getBytes());
    }

    public static String byteToHexString(final int length) {
        final byte[] one = new byte[1];
        one[0]=(byte) length;
        return byteArrayToHexString(one);
    }

    public static String getSubString(final String data, final String begin, final String end) {
        try {
            final int indexBegin = data.indexOf(begin);
            final String content = data.substring(indexBegin + begin.length());
            final int indexEnd = indexBegin + begin.length() + content.indexOf(end);

            final String substring = data.substring(indexBegin + begin.length(), indexEnd);

            return substring;
        } catch (final Exception e) {
            return "";
        }
    }
}
