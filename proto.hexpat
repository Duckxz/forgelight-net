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
  MULTI_MESSAGE = 0x19,
  FATAL_ERROR = 0x1d,
  FATAL_ERROR_REPLY = 0x1e
};


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

struct SessionRequest<auto Compression, auto IsSubPacket> {
    u32 crc_length;
    u32 session_id;
    u32 udp_length;
    char protocol[];
};

struct SessionReply<auto Compression, auto IsSubPacket> {
    u32 session_id;
    u32 crc_seed;
    u8 crc_length;
    u16 compression;
    u32 udp_length;
};

struct Disconnect<auto Compression, auto IsSubPacket> {
};

struct Ping<auto Compression, auto IsSubPacket> {

};

struct NetStatusRequest<auto Compression, auto IsSubPacket> {
};

struct NetStatusReply<auto Compression, auto IsSubPacket> {
};

struct Data<auto TotalLength, auto Compression, auto IsSubPacket> {
    if (Compression && !IsSubPacket) {
        padding[1];
    }
    
    if (IsSubPacket) {
        u16 sequence = 0;
        padding[sizeof(u16)];
    } else {
        u16 sequence;
    }
    if (Compression && !IsSubPacket) {
        u8 data[TotalLength - 2];
    } else {
        u8 data[TotalLength - 3];
    }
};

struct DataFragment<auto TotalLength, auto Compression, auto IsSubPacket> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
    if (IsSubPacket) {
        u16 crc = 0;
        padding[sizeof(u16)];
    } else {
        u16 crc;
    }
    u8 data[TotalLength - $];
};

struct OutOfOrder<auto Compression, auto IsSubPacket> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
};

struct Ack<auto Compression, auto IsSubPacket> {
    if (Compression) {
        padding[1];
    }
    u16 sequence;
};

// Special packets that go after everything else

using MultiPacketSubPacket;
struct MultiPacket<auto TotalLength, auto Compression, auto IsSubPacket> {
    if (Compression) {
        padding[1];
    }
    
    MultiPacketSubPacket subpackets[while($ < TotalLength - 2)];
};

struct MultiPacketSubPacket {
    DataLength datalength;
    padding[datalength.numBytes];

    // Inlining this
    /*TransportPacketType type;
    
    match (type) {
        (TransportPacketType::SESSION_REQUEST): SessionRequest<Compression, IsSubPacket> session_request;
        (TransportPacketType::SESSION_REPLY): SessionReply<Compression, IsSubPacket> session_reply;
        (TransportPacketType::MULTI_PACKET): MultiPacket<sizeof($), Compression, IsSubPacket> multi_packet;
        (TransportPacketType::DISCONNECT): Disconnect<Compression, IsSubPacket> disconnect;
        (TransportPacketType::PING): Ping<Compression, IsSubPacket> ping;
        (TransportPacketType::NETSTATUS_REQUEST): NetStatusRequest<Compression, IsSubPacket> netstatus_request;
        (TransportPacketType::NETSTATUS_REPLY): NetStatusReply<Compression, IsSubPacket> netstatus_reply;
        (TransportPacketType::DATA): Data<sizeof($), Compression, IsSubPacket> data;
        (TransportPacketType::DATA_FRAGMENT): DataFragment<sizeof($), Compression, IsSubPacket> data_fragment;
        (TransportPacketType::OUT_OF_ORDER): OutOfOrder<Compression, IsSubPacket> out_of_order;
        (TransportPacketType::ACK): Ack<Compression, IsSubpacket> ack;
    }*/
};

struct TransportPacket<auto Compression, auto IsSubPacket> {
    TransportPacketType type;
    
    match (type) {
        (TransportPacketType::SESSION_REQUEST): SessionRequest<Compression, IsSubPacket> session_request;
        (TransportPacketType::SESSION_REPLY): SessionReply<Compression, IsSubPacket> session_reply;
        (TransportPacketType::MULTI_PACKET): MultiPacket<sizeof($), Compression, IsSubPacket> multi_packet;
        (TransportPacketType::DISCONNECT): Disconnect<Compression, IsSubPacket> disconnect;
        (TransportPacketType::PING): Ping<Compression, IsSubPacket> ping;
        (TransportPacketType::NETSTATUS_REQUEST): NetStatusRequest<Compression, IsSubPacket> netstatus_request;
        (TransportPacketType::NETSTATUS_REPLY): NetStatusReply<Compression, IsSubPacket> netstatus_reply;
        (TransportPacketType::DATA): Data<sizeof($), Compression, IsSubPacket> data;
        (TransportPacketType::DATA_FRAGMENT): DataFragment<sizeof($), Compression, IsSubPacket> data_fragment;
        (TransportPacketType::OUT_OF_ORDER): OutOfOrder<Compression, IsSubPacket> out_of_order;
        (TransportPacketType::ACK): Ack<Compression, IsSubpacket> ack;
    }
};

bool compression = true;
TransportPacket<true, false> packet @ 0x0;