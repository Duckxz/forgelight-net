#pragma endian big

import std.io;
import std.mem;

enum TransportPacketType : u16 {
  SESSION_REQUEST = 0x01,
  SESSION_REPLY = 0x02,
  MULTI_PACKET = 0x03,
  UNK_4 = 0x04,
  DISCONNECT = 0x05,
  PING = 0x06,
  NETSTATUS_REQUEST = 0x07,
  NETSTATUS_REPLY = 0x08,
  DATA = 0x09,
  DATA_FRAGMENT = 0x0d,
  OUT_OF_ORDER = 0x11,
  ACK = 0x15,
  FATAL_ERROR = 0x1d,
  FATAL_ERROR_REPLY = 0x1e
};

using TransportPacket;

fn readDataLength(u32 offset, ref u32 numBytes) {
    u8 dataLength = std::mem::read_unsigned(offset, 1, std::mem::Endian::Big);
    if (dataLength == 0xFF) {
        if (std::mem::read_unsigned(offset+1, 1, std::mem::Endian::Big) == 0xFF && std::mem::read_unsigned(offset+2, 1, std::mem::Endian::Big) == 0xFF) {
            dataLength = std::mem::read_unsigned(offset+3, 4, std::mem::Endian::Big);
            numBytes = 7;
        } else if (std::mem::read_unsigned(offset+1, 1, std::mem::Endian::Big) > 0) {
            dataLength = std::mem::read_unsigned(offset+1, 2, std::mem::Endian::Big);
            numBytes = 3;
        } else {
            numBytes = 1;
        }
    } else {
        numBytes = 1;
    }
    return dataLength;
};

struct DataLength {
    u32 dataLength = std::mem::read_unsigned($, 1, std::mem::Endian::Big);
    u32 numBytes = 1;

    if (dataLength == 0xFF) {
        u8 byte1 = std::mem::read_unsigned($+1, 1, std::mem::Endian::Big);
        u8 byte2 = std::mem::read_unsigned($+2, 1, std::mem::Endian::Big);
        
        if (byte1 == 0xFF && byte2 == 0xFF) {
            dataLength = std::mem::read_unsigned($+3, 4, std::mem::Endian::Big);
            numBytes = 7;
        } else if (byte1 > 0) {
            dataLength = std::mem::read_unsigned($+1, 2, std::mem::Endian::Big);
            numBytes = 3;
        } else {
            numBytes = 1;
        }
    }
};

struct SessionRequest {
    u32 crc_length;
    u32 session_id;
    u32 udp_length;
    char protocol[];
};

struct SessionReply {
    u32 session_id;
    u32 crc_seed;
    u8 crc_length;
    u16 compression;
    u32 udp_length;
};

struct MultiPacketSubPacket<auto TotalLength> {
    DataLength datalength;
    
    padding[datalength.numBytes];
    
    TransportPacket packet;
    
};

struct MultiPacket<auto TotalLength, auto Compression> {
    if (Compression) {
        padding[1];
    }
    
    MultiPacketSubPacket<TotalLength> subpackets[while($ < TotalLength - 2)];
};

struct Disconnect {
};

struct Ping {

};

struct NetStatusRequest {
};

struct NetStatusReply {
};

struct Data<auto TotalLength, auto Compression> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
    u8 data[TotalLength - 2];
};

struct DataFragment<auto TotalLength, auto Compression> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
    u16 crc;
    u8 data[TotalLength - $];
};

struct OutOfOrder<auto Compression> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
};

struct Ack<auto Compression> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
};


struct TransportPacket {
    TransportPacketType type;
    
    match (type) {
        (TransportPacketType::SESSION_REQUEST): SessionRequest session_request;
        (TransportPacketType::SESSION_REPLY): SessionReply session_reply;
        (TransportPacketType::MULTI_PACKET): MultiPacket<sizeof($), true> multi_packet;
        (TransportPacketType::DISCONNECT): Disconnect disconnect;
        (TransportPacketType::PING): Ping ping;
        (TransportPacketType::NETSTATUS_REQUEST): NetStatusRequest netstatus_request;
        (TransportPacketType::NETSTATUS_REPLY): NetStatusReply netstatus_reply;
        (TransportPacketType::DATA): Data<sizeof($), true> data;
        (TransportPacketType::DATA_FRAGMENT): DataFragment<sizeof($), true> data_fragment;
        (TransportPacketType::OUT_OF_ORDER): OutOfOrder<true> out_of_order;
        (TransportPacketType::ACK): Ack<true> ack;
    }
};

TransportPacket packet @ 0x0;